// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;
import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";

contract BeaconChainProofHarness {

    function verifyValidatorRootAndBalanceRootAgainstBlockRoot(
        bytes32 blockRoot,
        bytes32 validatorListRoot,
        bytes32 balanceListRoot,
        bytes32[] memory multiProof
    ) external view {
        BeaconChainProofs.verifyValidatorRootAndBalanceRootAgainstBlockRoot({
            blockRoot: blockRoot,
            validatorListRoot: validatorListRoot,
            balanceListRoot: balanceListRoot,
            multiProof: multiProof
        });
    }

    function verifyValidatorBalancesProof(
        bytes32 balanceListRoot,
        bytes32[] memory proof,
        uint40[] memory validatorIndices,
        bytes32[] memory validatorBalances
    ) external view {
        BeaconChainProofs.verifyValidatorsBalance({
            balanceListRoot: balanceListRoot,
            validatorIndices: validatorIndices,
            validatorBalances: validatorBalances,
            proof: proof
        });
    }

    function verifyValidatorFields(
        bytes32 validatorListRoot,
        bytes32[][] memory validatorFields,
        bytes32[] memory proof,
        uint40[] memory validatorIndices
    ) external view {
        BeaconChainProofs.verifyValidatorFields({
            validatorListRoot:validatorListRoot,
            validatorFields: validatorFields,
            proof: proof,
            validatorIndices: validatorIndices
        });
    }
}

