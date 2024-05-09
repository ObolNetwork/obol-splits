// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import "forge-std/Test.sol";

import { StateProofVerifierV1 } from "src/verifiers/StateProofVerifierV1.sol";
import { StateProofVerifierHarnessV1 } from "src/test/harness/StateProofVerifierHarnessV1.sol";
import { ProofParser } from "./ProofParser.sol";
import { BeaconChainProofs } from "src/libraries/BeaconChainProof.sol";


contract StateProofVerifierV1Test is Test {

    StateProofVerifierV1 verifier;
    StateProofVerifierHarnessV1 harnessV1;
    ProofParser parser;

    function setUp() public {
        verifier = new StateProofVerifierV1();
        harnessV1 = new StateProofVerifierHarnessV1();
        parser = new ProofParser();
    }

    function test_verifyPartialWithdrawal() external {
        parser.setJSONPath("./src/test/test-data/partialWithdrawalProof_Latest.json");

        (
            ,
            BeaconChainProofs.WithdrawalProof memory withdrawalProof,
            bytes memory validatorFieldsProof,
            bytes32[] memory validatorFields,
            bytes32[] memory withdrawalFields
        ) = parser.values();

        harnessV1.verifyWithdrawalWithBeaconStateRoot(
            parser.getBeaconStateRoot(),
            withdrawalProof,
            validatorFieldsProof,
            validatorFields,
            withdrawalFields
        );
    }
}