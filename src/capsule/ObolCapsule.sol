// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IETHPOSDeposit} from "src/interfaces/IETHPOSDeposit.sol";
import {IProofVerifier} from "src/interfaces/IProofVerifier.sol";
import {IObolCapsule} from "src/interfaces/IObolCapsule.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";
import {IObolCapsuleFactory} from "src/interfaces/IObolCapsuleFactory.sol";
import {ObolCapsuleStorageV1} from "src/capsule/ObolCapsuleStorageV1.sol";
import {StateProofVerifierV1} from "src/capsule/verifiers/StateProofVerifierV1.sol";


/// @title ObolCapsule
/// @author Obol
/// @notice A composable state proof based staking contract
contract ObolCapsule is ObolCapsuleStorageV1 {

    error ObolCapsule__InvalidProofs();
    error ObolCapsule__ValidatorExitProofAlreadySubmitted(uint256 validatorIndex);

    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address;

    /// -----------------------------------------------------------------------
    /// storage - constants & immutables
    /// -----------------------------------------------------------------------

    uint256 internal constant ADDRESS_BITS = 160;
    uint256 internal constant PERCENTAGE_SCALE = 1e5;
    uint256 internal constant BITS_PER_UINT256 = 256;
    uint256 internal constant BIT_SET = 1;

    /// @notice This is the beacon chain deposit contract
    IETHPOSDeposit public immutable ethDepositContract;

    /// @notice fee share
    uint256 public immutable feeShare;

    /// @notice fee recipient
    address public immutable feeRecipient;

    /// @dev version
    uint256 internal constant VERSION = 0x1;

    /// @dev effective balance
    uint256 internal constant MIN_EFFECTIVE_BALANCE = 32 ether;

    constructor(
        IETHPOSDeposit _ethDepositContract,
        uint256 genesisTime,
        address _feeRecipient,
        uint256 _feeShare
    ) StateProofVerifierV1(genesisTime) {
        if (_feeShare >= PERCENTAGE_SCALE) revert Invalid_FeeShare(_feeShare);
        if (_feeShare > 0 && _feeRecipient == address(0)) revert Invalid_FeeRecipient();

        ethDepositContract = _ethDepositContract;
        feeShare = _feeShare;
        feeRecipient = _feeRecipient;

        _disableInitializers();
    }

    function initialize(
        address _principalRecipient,
        address _rewardRecipient,
        address _recoveryAddress
    ) external initializer {
        principalRecipient = _principalRecipient;
        rewardRecipient = _rewardRecipient;
        recoveryAddress = _recoveryAddress;
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
    /// @param oracleTimestamp oracle timestamp 
    /// @param vbProof validator list and balance list proof
    /// @param balanceProof validator balances proof
    /// @param validatorProof validator fields proof
    function processValidatorExit(
        uint64 oracleTimestamp,
        BeaconChainProofs.ValidatorListAndBalanceListRootProof calldata vbProof,
        BeaconChainProofs.BalanceProof calldata balanceProof,
        BeaconChainProofs.ValidatorProof calldata validatorProof
    ) external returns (uint256 totalExitedBalance) {
        /// Checks
        totalExitedBalance = _verifyExit(oracleTimestamp, vbProof, balanceProof, validatorProof);

        // Verify that the an already processed validator is not being re-submitted
        _verifyValidatorExitProofHasNotBeenSubmitted(
            validatorProof.validatorIndices
        );

        /// Effects
        
        /// Write to storage
        capsuleInfo.pendingStakeToClaim += uint128(totalExitedBalance);
        _storeValidatorIndices(validatorProof.validatorIndices);
        
        emit ValidatorExit(
            uint256(oracleTimestamp),
            totalExitedBalance
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
        if (principal > 0) principalRecipient.safeTransferETH(principal);
        if (rewards > 0) rewardRecipient.safeTransferETH(rewards);
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
        fee = (amount * feeShare) / PERCENTAGE_SCALE;
        // transfer to reward recipient
        reward = amount - fee;
    }

    /// Recover tokens to a recipient
    /// @param token Token to recover
    function recoverFunds(address token) external payable {
        /// checks
        address _recoveryAddress = recoveryAddress;

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
        BeaconChainProofs.ValidatorListAndBalanceListRootProof calldata vbProof,
        BeaconChainProofs.BalanceProof calldata balanceProof,
        BeaconChainProofs.ValidatorProof calldata validatorProof
    ) external view returns (uint256 totalExitedBalance) {
       return _verifyExit(oracleTimestamp, vbProof, balanceProof, validatorProof);
    }

    /// @dev Encodes withdrawal credentials
    function capsuleWithdrawalCredentials() public view returns (bytes memory) {
        return abi.encodePacked(bytes1(uint8(1)), bytes11(0), address(this));
    }

    /// @dev Returns if a validator exit proof has been submitted 
    function getValidatorExitProofSubmitted(uint40 validatorIndex) external view returns (bool posted) {
        posted = _validatorExitProofHasBeenSubmitted(validatorIndex);
    }

    /// @dev verify exit proofs
    /// @param oracleTimestamp passed in oracle timestamp
    function _verifyExit(
        uint64 oracleTimestamp,
        BeaconChainProofs.ValidatorListAndBalanceListRootProof calldata vbProof,
        BeaconChainProofs.BalanceProof calldata balanceProof,
        BeaconChainProofs.ValidatorProof calldata validatorProof
    ) internal view returns ( uint256 totalExitedBalance) {
        bytes32 withdrawalCredentials = bytes32(capsuleWithdrawalCredentials());
        (
            totalExitedBalance
        ) = verifyExitProof(
            oracleTimestamp,
            withdrawalCredentials,
            vbProof,
            balanceProof,
            validatorProof
        );
    }

    function _setBitValue(uint256 position) internal pure returns(uint256 newValue) {
        newValue = (newValue | ((1) << position));
    }

    function _getPositionValue(uint256 input, uint256 position) internal pure returns (uint256) {
        uint256 mask = 1 << position;
        uint256 maskedInput = input & mask;
        return uint256 (maskedInput >> position);
    }

    function _isBitSet(uint256 input, uint256 position) internal pure returns (bool) {
        return _getPositionValue(input, position) == BIT_SET;
    }

    function _convertValidatorIndexToBitPos(uint256 validatorIndex) internal pure returns (uint256 index, uint256 position) {
        index = validatorIndex / BITS_PER_UINT256;
        position = validatorIndex % BITS_PER_UINT256;
    }

    function _verifyValidatorExitProofHasNotBeenSubmitted(uint40[] calldata validatorIndices) internal view {
        uint256 validatorIndicesSize = validatorIndices.length; 
        for (uint256 i = 0; i < validatorIndicesSize; i++) {
            if (_validatorExitProofHasBeenSubmitted(validatorIndices[i]) == true) {
                revert ObolCapsule__ValidatorExitProofAlreadySubmitted(validatorIndices[i]);
            }
        }
    }

    function _validatorExitProofHasBeenSubmitted(uint40 validatorIndex) internal view returns (bool posted) {
        (uint256 index,  uint256 position) = _convertValidatorIndexToBitPos(validatorIndex);
        uint256 exitValidatorsMap = exitedValidators[index];
        posted = _isBitSet(exitValidatorsMap, position);
    }

    function _storeValidatorIndices(uint40[] calldata validatorIndices) internal {
        uint256 validatorIndicesSize = validatorIndices.length;
        
        uint256 prevIndex = type(uint256).max;
        uint256 currentExitValidatorsMap;

        for (uint256 i = 0; i < validatorIndicesSize; i++) {
            (uint256 index,  uint256 position) = _convertValidatorIndexToBitPos(validatorIndices[i]);
            if (prevIndex == type(uint256).max) {
                // store map 
                currentExitValidatorsMap = exitedValidators[index];
                prevIndex = index;
            } else if (prevIndex != index) {

                // Write To Storage
                exitedValidators[prevIndex] = currentExitValidatorsMap;

                // Change
                prevIndex = index;
                currentExitValidatorsMap = exitedValidators[index]; 
            }

            // update bit
            currentExitValidatorsMap = _setBitValue(position);
        }
    }
}