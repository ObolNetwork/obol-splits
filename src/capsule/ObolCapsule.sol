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

    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address;

    struct Principal {
        /// @dev exited stake 
        uint128 exitedStake;
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
    mapping (bytes32 validatorPubkeyHash => IProofVerifier.VALIDATOR_STATUS status) public validators;

    /// @notice Tracks the amount of stake
    Principal public principalAmount;


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

       IProofVerifier.VALIDATOR_STATUS status = validators[pubkeyHash];

        // @NB We don't validate stake size because EIP-7251 
        // could enable validator effective balance top up

        /// Effects
        if (status == IProofVerifier.VALIDATOR_STATUS.INACTIVE) {
            validators[pubkeyHash] = IProofVerifier.VALIDATOR_STATUS.ACTIVE;
        }

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
    /// @param oracleTimestamp oracle timestamp 
    /// @param exitProof a merkle multi-proof of exited validators
    // @TODO do for 1 single validator first in one block ✅
    // then figure out for multiple validators in one block using historical summaries
    // then figure out for multiple validators in multiple blocks historical summaries
    function processValidatorExit(
        uint64 oracleTimestamp,
        bytes calldata exitProof
    ) external returns (
        uint256 totalExitedBalance,
        bytes32[] memory validatorPubkeyHashses
    ) {
        /// Checks

        // we ensure the validator has exited i.e. withdrawable_epoch and exit_epoch have been set
        // we than verify the balance
        // we then add the balance to pendingStakeToClaim
        
        // @TODO for slashed validators figure out how to achieve ensuring the 
        // proof is posted after the second penalty is applied
       (
            totalExitedBalance,
            validatorPubkeyHashses
       ) = _verifyExit(oracleTimestamp, exitProof);
        
        /// Effects
        uint256 i = 0;
        uint256 size = validatorPubkeyHashses.length;

        for (; i < size;) {
            bytes32 validatorPubkeyHash = validatorPubkeyHashses[i];
            
            if (validators[validatorPubkeyHash] != IProofVerifier.VALIDATOR_STATUS.ACTIVE) {
                revert Invalid_ValidatorPubkey(validatorPubkeyHash);
            }

            // Write to Storage
            validators[validatorPubkeyHash] = IProofVerifier.VALIDATOR_STATUS.WITHDRAWN;

            unchecked {
                i++;
            }
        }

        /// Write to storage
        principalAmount.pendingStakeToClaim += uint128(totalExitedBalance);

        emit ValidatorExit(
            uint256(oracleTimestamp),
            totalExitedBalance,
            validatorPubkeyHashses
      );

    }

    /// @notice Distribute ETH available in the contract
    function distribute() external {
        Principal memory currentPrincipalData = principalAmount;
        uint256 currentBalance = address(this).balance;

        if (currentBalance == 0) revert Invalid_Balance();

        (
            uint256 principal,
            uint256 rewards,
            uint256 fee
        ) = _calculateDistribution(currentBalance, currentPrincipalData);

        /// Effects
        if (principal > 0) {
            currentPrincipalData.pendingStakeToClaim -= uint128(principal);
            currentPrincipalData.exitedStake += uint128(principal);
        }

        /// Write to storage
        principalAmount = currentPrincipalData;

        /// Interactions
        if (principal > 0) principalRecipient().safeTransferETH(principal);
        if (rewards > 0) rewardRecipient().safeTransferETH(rewards);
        if (fee > 0) feeRecipient.safeTransferETH(fee);

        emit DistributeFunds(principal, rewards, fee);
    }

    function _calculateDistribution(uint256 balance, Principal memory currentPrincipal) 
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
        bytes32[] memory validatorPubkeyHashses
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
        bytes32[] memory validatorPubkeyHashses
    ) {
        IProofVerifier proofVerifier = capsuleFactory.getVerifier();
        ( 
            totalExitedBalance,
            validatorPubkeyHashses
        ) = proofVerifier.verifyExitProof(oracleTimestamp, proof);
    }
}
