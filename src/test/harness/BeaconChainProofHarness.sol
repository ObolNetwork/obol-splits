// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;
import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";

contract BeaconChainProofHarness {

    function verifyValidatorRootAgainstBlockRoot(
        bytes32 blockRoot,
        BeaconChainProofs.ValidatorRegistryProof calldata vProof
    ) external view {
        BeaconChainProofs.verifyValidatorListRootAgainstBlockRoot({
            beaconBlockRoot: blockRoot,
            proof: vProof
        });
    }

    function verifyBalanceRootAgainstBlockRoot(
        bytes32 blockRoot,
        BeaconChainProofs.BalanceRegistryProof calldata vProof
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
            balanceListRoot: balanceListRoot,
            validatorIndex: validatorIndex,
            proof: proof
        });
    }

    function verifyMultiValidatorBalancesProof(
        bytes32 balanceListRoot,
        bytes32[] calldata proof,
        uint40[] memory validatorIndices,
        bytes32[] memory validatorBalances
    ) external pure returns (uint256[] memory) {
        return BeaconChainProofs.verifyMultipleValidatorsBalance({
            balanceListRoot: balanceListRoot,
            validatorIndices: validatorIndices,
            validatorBalanceRoots: validatorBalances,
            proof: proof
        });
    }

    function verifyMultiValidatorFields(
        bytes32 validatorListRoot,
        bytes32[][] calldata validatorFields,
        bytes32[] calldata proof,
        uint40[] calldata validatorIndices
    ) external pure {
        BeaconChainProofs.verifyMultipleValidatorFields({
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