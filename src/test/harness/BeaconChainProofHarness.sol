// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;
import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";

contract BeaconChainProofHarness {

    function verifyValidatorRootAgainstBlockRoot(
        bytes32 blockRoot,
        BeaconChainProofs.ValidatorListContainerProof calldata vProof
    ) external view {
        BeaconChainProofs.verifyValidatorListRootAgainstBlockRoot({
            beaconBlockRoot: blockRoot,
            proof: vProof
        });
    }

    function verifyBalanceRootAgainstBlockRoot(
        bytes32 blockRoot,
        BeaconChainProofs.BalanceContainerProof calldata vProof
    ) external view {
        BeaconChainProofs.verifyBalanceRootAgainstBlockRoot({
            beaconBlockRoot: blockRoot,
            proof: vProof
        });
    }

    function verifyValidatorBalance(
        bytes32 balanceListRoot,
        uint40 validatorIndex,
        BeaconChainProofs.BalanceProof calldata proof
    ) external view {
        BeaconChainProofs.verifyValidatorBalance({
            balanceContainerRoot: balanceListRoot,
            validatorIndex: validatorIndex,
            proof: proof
        });
    }

    function verifyMultiValidatorBalancesProof(
        bytes32 balanceListRoot,
        bytes32[] calldata proof,
        uint40[] memory validatorIndices,
        bytes32[] memory validatorBalances
    ) external view {
        BeaconChainProofs.verifyMultiValidatorsBalance({
            balanceListRoot: balanceListRoot,
            validatorIndices: validatorIndices,
            validatorBalances: validatorBalances,
            proof: proof
        });
    }

    function verifyMultiValidatorFields(
        bytes32 validatorListRoot,
        bytes32[][] calldata validatorFields,
        bytes32[] calldata proof,
        uint40[] calldata validatorIndices
    ) external view {
        BeaconChainProofs.verifyMultiValidatorFields({
            validatorListRoot:validatorListRoot,
            validatorFields: validatorFields,
            proof: proof,
            validatorIndices: validatorIndices
        });
    }

    function verifyValidatorFields(
        bytes32 validatorListRoot,
        bytes32[] calldata validatorFields,
        bytes calldata validatorFieldsProof,
        uint40 validatorIndex
    ) external view {
        BeaconChainProofs.verifyValidatorFields({
            validatorListRoot:validatorListRoot,
            validatorFields: validatorFields,
            validatorFieldsProof: validatorFieldsProof,
            validatorIndex: validatorIndex
        });
    }

   function getPubkeyHash(bytes32[] calldata validatorFields) public pure returns (bytes32) {
        return BeaconChainProofs.getPubkeyHash({
            validatorFields: validatorFields
        });
    }
}