// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;
import "forge-std/Test.sol";
import {Merkle} from "src/libraries/Merkle.sol";
import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";
import { ProofParser } from "./ProofParser.sol";
import {BeaconChainProofHarness} from "src/test/harness/BeaconChainProofHarness.sol";

contract BeaconChainProofTest__VBListRootAgainstBlockRootProof is Test {

    error BeaconChainProofs__InvalidValidatorRootandBalanceRootProof();
    error BeaconChainProofs__InvalidProofSize();

    ProofParser parser;
    BeaconChainProofHarness beaconChainProofHarness;

    function setUp() public {
        parser = new ProofParser();
        string memory filePath = "./src/test/test-data/ValidatorAndBalanceListRoot-proof.json";
        parser.setJSONPath(filePath);
        beaconChainProofHarness = new BeaconChainProofHarness();
    }

    function test_VerifyCorrectVBListRootAgainstBlockRootProof() external {
        beaconChainProofHarness.verifyValidatorRootAndBalanceRootAgainstBlockRoot({
            blockRoot: parser.getBlockRoot(),
            validatorListRoot: parser.getValidatorListRoot(),
            balanceListRoot: parser.getBalanceListRoot(),
            multiProof: parser.getVBListRootAgainstBlockRootProof()
        });
    }

    function test_CannotVerifyInCorrectVBListRootAgainstBlockRootProof() external {
        bytes32 blockRoot = parser.getBlockRoot();
        bytes32 validatorListRoot  = parser.getValidatorListRoot();
        bytes32 balanceListRoot    =  parser.getBalanceListRoot();
        bytes32[] memory proof     = parser.getVBListRootAgainstBlockRootProof();
        proof[0] = 0x0000000000000000000000000000000000000000000000000000000000000001;

        vm.expectRevert(BeaconChainProofs__InvalidValidatorRootandBalanceRootProof.selector);
        beaconChainProofHarness.verifyValidatorRootAndBalanceRootAgainstBlockRoot({
            blockRoot: blockRoot,
            validatorListRoot: validatorListRoot,
            balanceListRoot: balanceListRoot,
            multiProof: proof
        });
    }

    function test_CannotVerifyInvalidProofSize() external {
        bytes32 blockRoot = parser.getBlockRoot();
        bytes32 validatorListRoot = parser.getValidatorListRoot();
        bytes32 balanceListRoot =  parser.getBalanceListRoot();
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = 0x0000000000000000000000000000000000000000000000000000000000000001;

        vm.expectRevert(BeaconChainProofs__InvalidProofSize.selector);
        beaconChainProofHarness.verifyValidatorRootAndBalanceRootAgainstBlockRoot({
            blockRoot: blockRoot,
            validatorListRoot: validatorListRoot,
            balanceListRoot: balanceListRoot,
            multiProof: proof
        });
    }
}


contract BeaconChainProofTest__VerifyValidatorsBalance is Test {
    error BeaconChainProofs__InvalidValidatorFieldsMerkleProof();

    ProofParser parser;
    BeaconChainProofHarness beaconChainProofHarness;

    bytes32 blockRoot;
    bytes32 balanceListRoot;
    bytes32[] validatorBalancesRoot;
    uint40[] validatorIndices;
    bytes32[] validatorBalancesAgainstBalanceRootProof;

    function setUp() public {
        parser = new ProofParser();
        string memory filePath = "./src/test/test-data/ValidatorBalance-proof.json";
        parser.setJSONPath(filePath);
        beaconChainProofHarness = new BeaconChainProofHarness();

        blockRoot = parser.getBlockRoot();
        balanceListRoot = parser.getBalanceListRoot();
        validatorBalancesRoot = parser.getValidatorBalancesRoot();
        validatorIndices = parser.getValiatorIndices();
        validatorBalancesAgainstBalanceRootProof = parser.getValidatorBalancesProof();
    }

    function test_CanVerifyValidatorsBalanceProof() external view {
        beaconChainProofHarness.verifyValidatorBalancesProof(
            balanceListRoot,
            validatorBalancesAgainstBalanceRootProof,
            validatorIndices,
            validatorBalancesRoot
        );
    }

    function test_CannotVerifyValidatorsBalanceProof() external {
        validatorBalancesAgainstBalanceRootProof[0] = 0x0000000000000000000000000000000000000000000000000000000000000001;
        
        vm.expectRevert(BeaconChainProofs__InvalidValidatorFieldsMerkleProof.selector);
        beaconChainProofHarness.verifyValidatorBalancesProof(
            balanceListRoot,
            validatorBalancesAgainstBalanceRootProof,
            validatorIndices,
            validatorBalancesRoot
        );
    }
}

contract BeaconChainProofTest__VerifyValidatorsFields is Test {

    error BeaconChainProofs__InvalidValidatorFieldsMerkleProof();

    ProofParser parser;
    BeaconChainProofHarness beaconChainProofHarness;

    bytes32 validatorListRoot;
    uint40[] validatorIndices;
    bytes32[][] validatorFields;
    bytes32[] validatorFieldsAgainstValidatorListProof;

    function setUp() public {
        parser = new ProofParser();
        string memory filePath = "./src/test/test-data/ValidatorFields-proof.json";
        parser.setJSONPath(filePath);
        beaconChainProofHarness = new BeaconChainProofHarness();

        validatorListRoot = parser.getValidatorListRoot();
        validatorIndices = parser.getValiatorIndices();
        validatorFields = parser.getValidatorFields(validatorIndices.length);
        validatorFieldsAgainstValidatorListProof = parser.getValidatorFieldsProof();
    }

    function test_CanVerifyValidatorsFieldsProof() public view {
        beaconChainProofHarness.verifyValidatorFields(
            validatorListRoot,
            validatorFields,
            validatorFieldsAgainstValidatorListProof,
            validatorIndices
        );
    }

    function test_CannotVerifyValidatorsFieldsProof() public {
        validatorFieldsAgainstValidatorListProof[0] = 0x0000000000000000000000000000000000000000000000000000000000000001;

        vm.expectRevert(BeaconChainProofs__InvalidValidatorFieldsMerkleProof.selector);
        beaconChainProofHarness.verifyValidatorFields(
            validatorListRoot,
            validatorFields,
            validatorFieldsAgainstValidatorListProof,
            validatorIndices
        );
    }
}