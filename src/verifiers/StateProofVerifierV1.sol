// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";
import {IProofVerifier} from "src/interfaces/IProofVerifier.sol";



/// @title StateProofVerifierV1
/// @author Obol
/// @notice A beacon state proof verifier staking contract
contract StateProofVerifierV1 is IProofVerifier {
    using BeaconChainProofs for *;

    error Invalid_Timestamp(uint64 timestamp);
    error Invalid_Inputs();

     /// @dev beacon roots contract
    address public constant BEACON_BLOCK_ROOTS_CONTRACT = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;


    uint256 public constant VERSION = 1;
    bytes32 public immutable HARDFORK;

    enum VALIDATOR_STATUS {
        INACTIVE, // doesnt exist
        ACTIVE, // staked on ethpos and withdrawal credentials are pointed to the EigenPod
        WITHDRAWN // withdrawn from the Beacon Chain
    }

    struct ValidatorInfo {
        // index of the validator in the beacon chain
        uint64 validatorIndex;
        // amount of beacon chain ETH restaked on EigenLayer in gwei
        uint64 restakedBalanceGwei;
        //timestamp of the validator's most recent balance update
        uint64 mostRecentBalanceUpdateTimestamp;
        // status of the validator
        VALIDATOR_STATUS status;
    }

    struct Withdrawal {
        bytes32 validatorPubKeyHash;
        uint256 amountToSendGwei;
        uint64 withdrawalTimestamp;
        // `@TODO add validator status
    }

    constructor() {
        HARDFORK = 'capella';
    }

    function verifyWithdrawal(
        uint64 oracleTimestamp,
        bytes calldata proof
    ) external override returns (Withdrawal memory verifiedWithdrawal) {
        (
            BeaconChainProofs.StateRootProof calldata stateRootProof,
            BeaconChainProofs.WithdrawalProof[] calldata withdrawalProofs,
            bytes[] calldata validatorFieldsProofs,
            bytes32[][] calldata validatorFields,
            bytes32[][] calldata withdrawalFields
        ) = abi.decode(proof);

        if (
            (validatorFields.length != validatorFieldsProofs.length) ||
            (validatorFieldsProofs.length != withdrawalProofs.length) ||
            (withdrawalProofs.length != withdrawalFields.length)
        ) {
            revert Invalid_Inputs();
        }

        // Verify passed-in beaconStateRoot against rovided block root:
        BeaconChainProofs.verifyStateRootAgainstLatestBlockRoot({
            latestBlockRoot: getBeaconBlockRootFromTimestamp(oracleTimestamp),
            beaconStateRoot: stateRootProof.beaconStateRoot,
            stateRootProof: stateRootProof.proof
        });

        uint256 amountToSendGwei;



    }

    function _verifyWithdrawal(
        bytes32 beaconStateRoot,
        BeaconChainProofs.WithdrawalProof calldata withdrawalProof,
        bytes calldata validatorFieldsProof,
        bytes32[] calldata validatorFields,
        bytes32[] calldata withdrawalFields
    ) internal returns (uint256 amountToSendGwei) {
        uint64 withdrawalTimestamp = withdrawalProof.getWithdrawalTimestamp();
        bytes32 validatorPubkeyHash = validatorFields.getPubkeyHash();

        BeaconChainProofs.verifyWithdrawal({
            beaconStateRoot: beaconStateRoot, 
            withdrawalFields: withdrawalFields, 
            withdrawalProof: withdrawalProof,
            denebForkTimestamp: eigenPodManager.denebForkTimestamp()
        });

        uint40 validatorIndex = withdrawalFields.getValidatorIndex();

        // Verify passed-in validatorFields against verified beaconStateRoot:
        BeaconChainProofs.verifyValidatorFields({
            beaconStateRoot: beaconStateRoot,
            validatorFields: validatorFields,
            validatorFieldsProof: validatorFieldsProof,
            validatorIndex: validatorIndex
        });

        uint64 withdrawalAmountGwei = withdrawalFields.getWithdrawalAmountGwei();

                
        /**
         * If the withdrawal
         * 's epoch comes after the validator's "withdrawable epoch," we know the validator        
         * has fully withdrawn, and we process this as a full withdrawal.
         */
        if (withdrawalProof.getWithdrawalEpoch() >= validatorFields.getWithdrawableEpoch()) {
            return
                _processFullWithdrawal(
                    validatorIndex,
                    validatorPubkeyHash,
                    withdrawalTimestamp,
                    podOwner,
                    withdrawalAmountGwei,
                    _validatorPubkeyHashToInfo[validatorPubkeyHash]
                );
        } else {
            return
                _processPartialWithdrawal(
                    validatorIndex,
                    withdrawalTimestamp,
                    podOwner,
                    withdrawalAmountGwei
                );
        }
        

    }

    function _processFullWithdrawal(
        uint40 validatorIndex,
        bytes32 validatorPubkeyHash,
        uint64 withdrawalTimestamp,
        address recipient,
        uint64 withdrawalAmountGwei,
        ValidatorInfo memory validatorInfo
    ) internal returns (uint256 amountToSendGwei) {
        /**
         * First, determine withdrawal amounts. We need to know:
         * 1. How much can be withdrawn immediately
         * 2. How much needs to be withdrawn via the EigenLayer withdrawal queue
         */

        if (validatorInfo.status != VALIDATOR_STATUS.WITHDRAWN) {
            activeValidatorCount--;
            validatorInfo.status = VALIDATOR_STATUS.WITHDRAWN;
        }

        validatorInfo.restakedBalanceGwei = 0;        
        _validatorPubkeyHashToInfo[validatorPubkeyHash] = validatorInfo;

        emit FullWithdrawalRedeemed(validatorIndex, withdrawalTimestamp, recipient, withdrawalAmountGwei);

        return verifiedWithdrawal;


    }


    /// @dev Returns the becaon block root based on timestamp
    /// @param timestamp timestamp to fetch state root 
    /// @return stateRoot beacon state root 
    function getBeaconBlockRootFromTimestamp(uint256 timestamp) public view returns (bytes32 stateRoot) {
        (bool ret, bytes memory data) = BEACON_BLOCK_ROOTS_CONTRACT.call(bytes.concat(bytes32(timestamp)));
        if (ret == false) revert Invalid_Timestamp(timestamp);

        stateRoot = bytes32(data);
    }




}