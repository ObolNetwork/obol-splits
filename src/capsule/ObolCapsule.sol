// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {Clone} from "solady/utils/Clone.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IETHPOSDeposit} from "src/interfaces/IETHPOSDeposit.sol";
import {IProofVerifier} from "src/interfaces/IProofVerifier.sol";
import {IObolCapsule} from "src/interfaces/IObolCapsule.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";
import {IObolCapsuleFactory} from "src/interfaces/IObolCapsuleFactory.sol";


/// @title ObolCapsule
/// @author Obol
/// @notice A composable state proof based staking contract
contract ObolCapsule is Clone, IObolCapsule {

    error ObolCapsule__InvalidProofs();

    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address;

    struct CapsuleData {
        /// @dev Last submitted exit epoch
        uint96 exitedStake;
        /// @dev Last submitted exit epoch
        uint64 lastSubmittedExitEpoch;
        /// @dev pending amount of stake to claim
        uint128 pendingStakeToClaim;
    }

    /// -----------------------------------------------------------------------
    /// storage - constants & immutables
    /// -----------------------------------------------------------------------

    uint256 internal constant ADDRESS_BITS = 160;
    uint256 internal constant PERCENTAGE_SCALE = 1e5;

    /// @notice This is the beacon chain deposit contract
    IETHPOSDeposit public immutable ethDepositContract;

    /// @notice capsule factory
    IObolCapsuleFactory public immutable capsuleFactory;

    /// @notice fee share
    uint256 public immutable feeShare;

    /// @notice fee recipient
    address public immutable feeRecipient;

    /// -----------------------------------------------------------------------
    /// storage - cwia offsets
    /// -----------------------------------------------------------------------
    
    // principalRecipient (address, 20 bytes),
    // rewardRecipient (address, 20 bytes),
    // reecoveryAddress (address, 20 bytes),

    // 0; first item
    uint256 internal constant PRINCIPAL_RECIPIENT_ADDRESS_OFFSET = 0;
    // 20 = principalAddress_offset (0) + rewardAddress_size (address, 20
    // bytes)
    uint256 internal constant REWARD_RECIPIENT_ADDRESS_OFFSET = 20;
    // 40 = rewardAddress_offset (20) + recoveryAddress_size (address, 20
    // bytes)
    uint256 internal constant RECOVERY_ADDRESS_OFFSET = 40;

    
    /// -----------------------------------------------------------------------
    /// storage
    /// -----------------------------------------------------------------------

    /// @notice validator pubkey hash to status
    // mapping (bytes32 validatorPubkeyHash => IProofVerifier.VALIDATOR_STATUS status) public validators;

    /// @notice Tracks capsule state
    CapsuleData public capsuleInfo;


    constructor(
        IETHPOSDeposit _ethDepositContract,
        IObolCapsuleFactory factory,
        address _feeRecipient,
        uint256 _feeShare
    ) {
        if (_feeShare >= PERCENTAGE_SCALE) revert Invalid_FeeShare(_feeShare);
        if (_feeShare > 0 && _feeRecipient == address(0)) revert Invalid_FeeRecipient();

        ethDepositContract = _ethDepositContract;
        capsuleFactory = factory;
        feeShare = _feeShare;
        feeRecipient = _feeRecipient;
    }

    /// @notice Create new validators
    /// @param pubkey validator public keys
    /// @param signature deposit validator signatures
    /// @param depositDataRoot deposit validator data roots
    function stake(
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot
    ) external payable override {
        bytes32 pubkeyHash = BeaconChainProofs.hashValidatorBLSPubkey(pubkey);

        /// Interaction
        ethDepositContract.deposit{value: msg.value}(
            pubkey,
            capsuleWithdrawalCredentials(), 
            signature, 
            depositDataRoot
        );
        
        emit ObolPodStaked(pubkeyHash, msg.value);
    }

    /// @notice Process a validator exits
    /// @dev !!!IMPORTANT!!! Submit exit proofs in order of least recent to most recent
    /// @param oracleTimestamp oracle timestamp 
    /// @param exitProof a merkle multi-proof of exited validators
    function processValidatorExit(
        uint64 oracleTimestamp,
        bytes calldata exitProof
    ) external returns (
        uint256 totalExitedBalance
    ) {
        /// Checks

        // @TODO verify withdrawal credential points to this contract
        // how do i know which vals has been used.

        // we ensure the validator has exited i.e. withdrawable_epoch and exit_epoch have been set
        // we than verify the balance
        // we then add the balance to pendingStakeToClaim
        
        // @TODO for slashed validators figure out how to achieve ensuring the 
        // proof is posted after the second penalty is applied
       uint256 leastMostRecentExitEpoch = 0;
       (
            totalExitedBalance,
            leastMostRecentExitEpoch
       ) = _verifyExit(oracleTimestamp, exitProof);
        
        /// Effects

        /// Load from  storage
        CapsuleData memory currentCapsuleInfo = capsuleInfo;

        if (currentCapsuleInfo.lastSubmittedExitEpoch > leastMostRecentExitEpoch) {
            revert ObolCapsule__InvalidProofs();
        }

        currentCapsuleInfo.lastSubmittedExitEpoch = uint64(leastMostRecentExitEpoch);
        currentCapsuleInfo.pendingStakeToClaim += uint128(totalExitedBalance);
        
        /// Write to storage
        capsuleInfo = currentCapsuleInfo;
        
        emit ValidatorExit(
            uint256(oracleTimestamp),
            totalExitedBalance,
            uint256(leastMostRecentExitEpoch)
       );

    }

    /// @notice Distribute ETH available in the contract
    function distribute() external {
        CapsuleData memory currentCapsuleData = capsuleInfo;
        uint256 currentBalance = address(this).balance;

        if (currentBalance == 0) revert Invalid_Balance();

        (
            uint256 principal,
            uint256 rewards,
            uint256 fee
        ) = _calculateDistribution(currentBalance, currentCapsuleData);

        /// Effects
        if (principal > 0) {
            currentCapsuleData.pendingStakeToClaim -= uint128(principal);
            currentCapsuleData.exitedStake += uint96(principal);
        }

        /// Write to storage
        capsuleInfo = currentCapsuleData;

        /// Interactions
        if (principal > 0) principalRecipient().safeTransferETH(principal);
        if (rewards > 0) rewardRecipient().safeTransferETH(rewards);
        if (fee > 0) feeRecipient.safeTransferETH(fee);

        emit DistributeFunds(principal, rewards, fee);
    }

    function _calculateDistribution(uint256 balance, CapsuleData memory currentPrincipal) 
        internal 
        view
        returns(
            uint256 principal,
            uint256 rewards,
            uint256 fee
        )
    {
        if (currentPrincipal.pendingStakeToClaim > 0) {
            if (balance > currentPrincipal.pendingStakeToClaim) {
                principal = currentPrincipal.pendingStakeToClaim;
                
                uint256 availableRewardToDistribute = balance - currentPrincipal.pendingStakeToClaim;
                (rewards, fee) = _calculateRewardDistribution(availableRewardToDistribute);
            } else {
                principal = balance;
            }
        } else {
            // distribute current balance has rewards
            (rewards, fee) = _calculateRewardDistribution(balance);
        }
    }

    function _calculateRewardDistribution(uint256 amount) internal view returns (uint256 reward, uint256 fee) {
        // charge obol fee on rewards
        fee = ( amount * feeShare) / PERCENTAGE_SCALE;
        // transfer to reward recipient
        reward = amount - fee;
    }

    /// Recover tokens to a recipient
    /// @param token Token to recover
    function recoverFunds(address token) external payable {
        /// checks
        address _recoveryAddress = recoveryAddress();

        /// effects
        
        /// interactions
        uint256 amount = ERC20(token).balanceOf(address(this));
        ERC20(token).safeTransfer(_recoveryAddress, amount);

        emit RecoverFunds(token, _recoveryAddress, amount);
    }

    /// @dev Verify withdrawal proof
    /// @param oracleTimestamp beacon stat
    function verfiyExitProof(
        uint64 oracleTimestamp,
        bytes calldata proof
    ) external view returns (
        uint256 totalExitedBalance,
        uint256 mostRecentExitEpoch
    ) {
       return _verifyExit(oracleTimestamp, proof);
    }

    /// Address that receives rewards
    /// @dev equivalent to address public immutable rewardRecipient;
    function rewardRecipient() public pure returns (address) {
        return _getArgAddress(REWARD_RECIPIENT_ADDRESS_OFFSET);
    }

    /// Address that receives rewards
    /// @dev equivalent to address public immutable principalRecipient;
    function principalRecipient() public pure returns (address) {
        return _getArgAddress(PRINCIPAL_RECIPIENT_ADDRESS_OFFSET);
    }

    /// Address to recover tokens to
    /// @dev equivalent to address public immutable recoveryAddress;
    function recoveryAddress() public pure returns (address) {
        return _getArgAddress(RECOVERY_ADDRESS_OFFSET);
    }

    /// @dev Encodes withdrawal credentials
    function capsuleWithdrawalCredentials() public view returns (bytes memory) {
        return abi.encodePacked(bytes1(uint8(1)), bytes11(0), address(this));
    }

    function _verifyExit(
        uint64 oracleTimestamp,
        bytes calldata proof
    ) internal view returns (
        uint256 totalExitedBalance,
        uint256 mostRecentExitEpoch
    ) {
        IProofVerifier proofVerifier = capsuleFactory.getVerifier();
        bytes32 withdrawalCredentials = bytes32(capsuleWithdrawalCredentials());
        ( 
            totalExitedBalance,
            mostRecentExitEpoch
        ) = proofVerifier.verifyExitProof(
            oracleTimestamp,
            withdrawalCredentials,
            proof
        );
    }
}
