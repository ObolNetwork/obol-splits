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

    struct ValidatorInfo {
        // timestamp of the validator's most withdrawal
        uint64 mostRecentOracleWithdrawalTimestamp;
        // status of the validator
        IProofVerifier.VALIDATOR_STATUS status;
    }

    /// -----------------------------------------------------------------------
    /// storage - constants & immutables
    /// -----------------------------------------------------------------------

    uint256 internal constant ADDRESS_BITS = 160;
    uint256 internal constant PERCENTAGE_SCALE = 1e5;

    /// @dev beacon roots contract
    address public constant BEACON_BLOCK_ROOTS_CONTRACT = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;

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

    /// @notice validator pubkey hash to information
    mapping (bytes32 => ValidatorInfo) public validators;


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

        ValidatorInfo storage info = validators[pubkeyHash];

        // @NB We don't validate stake size because EIP-7251 
        // could enable validator effective balance top up

        /// Effects
        if (info.status == IProofVerifier.VALIDATOR_STATUS.INACTIVE) {
            validators[pubkeyHash] = ValidatorInfo(0, IProofVerifier.VALIDATOR_STATUS.ACTIVE);
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

    /// @notice Create new validators
    /// @param oracleTimestamp oracle timestamp 
    /// @param proof beacon state withdrawal proof
    // @TODO do for 1 single validator first in one block ✅
    // then figure out for multiple validators in one block using historical summaries
    // then figure out for multiple validators in multiple blocks historical summaries
    function withdraw(
        uint64 oracleTimestamp,
        bytes calldata proof
    ) external {
        
        /// Checks
        IProofVerifier.Withdrawal memory withdrawal = _verifyWithdrawal(oracleTimestamp, proof);
        
        /// Effects
        ValidatorInfo storage validatorInfo = validators[withdrawal.validatorPubKeyHash];

        validatorInfo.mostRecentOracleWithdrawalTimestamp = withdrawal.withdrawalTimestamp;
        validatorInfo.status = withdrawal.status;

        /// Interaction

        /// the validator has been exited
        if (withdrawal.status == IProofVerifier.VALIDATOR_STATUS.WITHDRAWN) {
            // send to principal recipient
            principalRecipient().safeTransferETH(withdrawal.amountToSendGwei);
        } else {
            // charge obol fee on rewards
            uint256 fee = (withdrawal.amountToSendGwei * feeShare) / PERCENTAGE_SCALE;
            // transfer fee to fee recipient
            feeRecipient.safeTransferETH(fee);
            // transfer to reward recipient
            uint256 amount = withdrawal.amountToSendGwei - fee;
            rewardRecipient().safeTransferETH(amount);
        }

        emit Withdraw(
            withdrawal.validatorPubKeyHash,
            withdrawal.amountToSendGwei,
            uint256(oracleTimestamp),
            uint256(withdrawal.status)
        );
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
    function verfiyWithdrawalProof(
        uint64 oracleTimestamp,
        bytes calldata proof
    ) external view returns (IProofVerifier.Withdrawal memory withdrawal) {
       withdrawal = _verifyWithdrawal(oracleTimestamp, proof);
    }

    /// Address that receives rewards
    /// @dev equivalent to address public immutable rewardRecipient;
    function rewardRecipient() public pure returns(address) {
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

    function _verifyWithdrawal(
        uint64 oracleTimestamp,
        bytes calldata proof
    ) internal view returns (IProofVerifier.Withdrawal memory withdrawal) {
        IProofVerifier proofVerifier = capsuleFactory.getVerifier();
        withdrawal = proofVerifier.verifyWithdrawal(oracleTimestamp, proof);

        ValidatorInfo storage validatorInfo = validators[withdrawal.validatorPubKeyHash];

        if (validatorInfo.status == IProofVerifier.VALIDATOR_STATUS.WITHDRAWN) {
            revert Invalid_ValidatorStatus();
        }

        if (withdrawal.withdrawalTimestamp < validatorInfo.mostRecentOracleWithdrawalTimestamp) {
            revert Invalid_ProofTimestamp(withdrawal.withdrawalTimestamp, validatorInfo.mostRecentOracleWithdrawalTimestamp);
        }
    }
}
