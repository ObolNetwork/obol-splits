// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";
import {IProofVerifier} from "src/interfaces/IProofVerifier.sol";



/// @title StateProofVerifierV1
/// @author Obol
/// @notice A beacon state proof verifier staking contract
contract StateProofVerifierV1 is IProofVerifier {
    using BeaconChainProofs for *;

    error Invalid_Inputs();

    /// @dev beacon roots contract
    address public constant BEACON_BLOCK_ROOTS_CONTRACT = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;
    
    /// @dev version
    uint256 public constant VERSION = 1;

    /// @dev hardfork it supports
    string public HARDFORK;

    constructor() {
        HARDFORK = 'cancun/deneb';
    }

    /// @dev verify Becaon chain validator withdrawals
    /// @param oracleTimestamp beacon block roots timestamp
    /// @param proof withdrawal proofs 
    function verifyExitProof(
        uint256 oracleTimestamp,
        bytes calldata proof
    ) external view override returns (
        uint256 totalExitedBalance,
        bytes32[] memory validatorPubkeyHashses
    ) {
        // BeaconChainProofs.StateRootProof memory stateRootProof,
        // BeaconChainProofs.BalanceContainerProof calldata balanceContainerProof,
        // bytes memory validatorFieldsProof,
        // bytes32[] memory validatorFields
        (
            BeaconChainProofs.StateRootProof memory stateRootProof,
            BeaconChainProofs.BalanceProof memory balanceProofs,
            BeaconChainProofs.ValidatorProof memory validatorProof,
            bytes32[] memory validatorFields
        ) = abi.decode(
            proof,
            (
                BeaconChainProofs.StateRootProof,
                BeaconChainProofs.BalanceProof,
                BeaconChainProofs.ValidatorProof,
                bytes32[]
            ));
            
        // Verify passed-in beaconStateRoot against provided block root:
        BeaconChainProofs.verifyStateRootAgainstLatestBlockRoot({
            latestBlockRoot: getBeaconBlockRootFromTimestamp(oracleTimestamp),
            beaconStateRoot: stateRootProof.beaconStateRoot,
            stateRootProof: stateRootProof.proof
        });

        return _verifyExitProofs(
            getBeaconBlockRootFromTimestamp(oracleTimestamp),
            withdrawalProofs,
            validatorFieldsProofs,
            validatorFields,
            withdrawalFields
        );
    }

    function _verifyExitProofs(
        
    ) internal view returns (
        uint256 totalExitedBalance,
        bytes32[] memory validatorPubkeyHashses
    ) {

    }

    // function _verifyWithdrawal(
    //     bytes32 beaconStateRoot,
    //     BeaconChainProofs.WithdrawalProof memory withdrawalProof,
    //     bytes memory validatorFieldsProof,
    //     bytes32[] memory validatorFields,
    //     bytes32[] memory withdrawalFields
    // ) internal view returns (Withdrawal memory withdrawal) {
    //     uint64 withdrawalTimestamp = withdrawalProof.getWithdrawalTimestamp();
    //     bytes32 validatorPubkeyHash = validatorFields.getPubkeyHash();

    //     BeaconChainProofs.verifyWithdrawal({
    //         beaconStateRoot: beaconStateRoot, 
    //         withdrawalFields: withdrawalFields, 
    //         withdrawalProof: withdrawalProof
    //     });

    //     uint40 validatorIndex = withdrawalFields.getValidatorIndex();

    //     // Verify passed-in validatorFields against verified beaconStateRoot:
    //     BeaconChainProofs.verifyValidatorFields({
    //         beaconStateRoot: beaconStateRoot,
    //         validatorFields: validatorFields,
    //         validatorFieldsProof: validatorFieldsProof,
    //         validatorIndex: validatorIndex
    //     });

    //     uint64 withdrawalAmountGwei = withdrawalFields.getWithdrawalAmountGwei();

    //     VALIDATOR_STATUS validatorStatus = VALIDATOR_STATUS.ACTIVE;
    //     /**
    //      * If the withdrawal
    //      * 's epoch comes after the validator's "withdrawable epoch," we know the validator        
    //      * has fully withdrawn, and we process this as a full withdrawal.
    //      */
    //     if (withdrawalProof.getWithdrawalEpoch() >= validatorFields.getWithdrawableEpoch()) {
    //         validatorStatus = VALIDATOR_STATUS.WITHDRAWN;
    //     }

    //     withdrawal = Withdrawal(
    //         validatorPubkeyHash,
    //         withdrawalAmountGwei,
    //         withdrawalTimestamp,
    //         validatorStatus
    //     );
    // }

    /// @dev Returns the becaon block root based on timestamp
    /// @param timestamp timestamp to fetch state root 
    /// @return stateRoot beacon state root 
    function getBeaconBlockRootFromTimestamp(uint256 timestamp) public view returns (bytes32 stateRoot) {
        (bool ret, bytes memory data) = BEACON_BLOCK_ROOTS_CONTRACT.staticcall(bytes.concat(bytes32(timestamp)));
        if (ret == false) revert Invalid_Timestamp(timestamp);

        stateRoot = bytes32(data);
    }


}