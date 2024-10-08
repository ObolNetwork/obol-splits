// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;
import "forge-std/Test.sol";
import {Merkle} from "src/libraries/Merkle.sol";
import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";
import { SymPodProofParser } from "./SymPodProofParser.sol";
import {BeaconChainProofHarness} from "src/test/harness/BeaconChainProofHarness.sol";

abstract contract BaseBeaconChainProofTest is Test {
    SymPodProofParser parser;
    BeaconChainProofHarness beaconChainProofHarness;


    function setUp() public virtual {
        parser = new SymPodProofParser();
        beaconChainProofHarness = new BeaconChainProofHarness();
    }
}

contract BeaconChainProofTest__ValidatorRootAgainstBlockRoot is BaseBeaconChainProofTest {
    error BeaconChainProofs__InvalidValidatorRootProof();

    bytes32 blockRoot;
    bytes32 validatorListRoot;
    function setUp() override public {
        super.setUp();
        string memory filePath = "./src/test/test-data/ValidatorListRootProof-proof.json";
        parser.setJSONPath(filePath);

        blockRoot = parser.getBlockRoot();
        validatorListRoot = parser.getValidatorListRoot();
    }

    function test_VerifyCorrectValidatorListRootProofAgainstBlockRoot() external {
        bytes memory validProof = parser.getValidatorListRootProofAgainstBlockRoot();

        beaconChainProofHarness.verifyValidatorRootAgainstBlockRoot(
            blockRoot,
            BeaconChainProofs.ValidatorListContainerProof({
                validatorListRoot: validatorListRoot,
                proof: validProof
            })
        );
    }

    function test_CannotVerifyCorrectIncorrectProofSize() external {
        bytes32[] memory proofArray = new bytes32[](1);
        proofArray[0] = 0x0000000000000000000000000000000000000000000000000000000000000001;
        bytes memory proof = abi.encodePacked(proofArray);

        vm.expectRevert(BeaconChainProofs.BeaconChainProofs__InvalidProofSize.selector);

        beaconChainProofHarness.verifyValidatorRootAgainstBlockRoot(
            blockRoot,
            BeaconChainProofs.ValidatorListContainerProof({
                validatorListRoot: validatorListRoot,
                proof: proof
            })
        );

    }

    function test_CannotVerifyInvalidProof() external {
        // switch the file to fetch another proof 
        string memory filePath = "./src/test/test-data/BalanceListRootProof-proof.json";
        parser.setJSONPath(filePath);
        bytes memory invalidProof = parser.getBalanceListRootProofAgainstBlockRoot();
        vm.expectRevert(BeaconChainProofs__InvalidValidatorRootProof.selector);
        beaconChainProofHarness.verifyValidatorRootAgainstBlockRoot(
            blockRoot,
            BeaconChainProofs.ValidatorListContainerProof({
                validatorListRoot: validatorListRoot,
                proof: invalidProof
            })
        );
    }


}

contract BeaconChainProofTest__VerifyBalanceRootAgainstBlockRoot is BaseBeaconChainProofTest {

    bytes32 blockRoot;
    bytes32 balanceListRoot;

    function setUp() override public {
        super.setUp();
        string memory filePath = "./src/test/test-data/BalanceListRootProof-proof.json";
        parser.setJSONPath(filePath);

        blockRoot = parser.getBlockRoot();
        balanceListRoot = parser.getBalanceListRoot();
    }


    function test_VerifyCorrectBalanceListRootProofAgainstBlockRoot() external {
        bytes memory validProof = parser.getBalanceListRootProofAgainstBlockRoot();

        beaconChainProofHarness.verifyBalanceRootAgainstBlockRoot(
            blockRoot,
            BeaconChainProofs.BalanceContainerProof({
                balanceListRoot: balanceListRoot,
                proof: validProof
            })
        );
    }

    function test_CannotVerifyInvalidProofSize() external {
        bytes32[] memory proofArray = new bytes32[](1);
        proofArray[0] = 0x0000000000000000000000000000000000000000000000000000000000000001;
        bytes memory validProof = abi.encodePacked(proofArray);
        
        vm.expectRevert(BeaconChainProofs.BeaconChainProofs__InvalidProofSize.selector);
        beaconChainProofHarness.verifyBalanceRootAgainstBlockRoot(
            blockRoot,
            BeaconChainProofs.BalanceContainerProof({
                balanceListRoot: balanceListRoot,
                proof: validProof
            })
        );
    }

    function test_CannotVerifyInvalidWithProof() external {
        string memory filePath = "./src/test/test-data/ValidatorListRootProof-proof.json";
        parser.setJSONPath(filePath);
        bytes memory invalidProof = parser.getValidatorListRootProofAgainstBlockRoot();

        vm.expectRevert(BeaconChainProofs.BeaconChainProofs__InvalidBalanceRootProof.selector);
        beaconChainProofHarness.verifyBalanceRootAgainstBlockRoot(
            blockRoot,
            BeaconChainProofs.BalanceContainerProof({
                balanceListRoot: balanceListRoot,
                proof: invalidProof
            })
        );
    }

}

contract BeaconChainProofTest__VerifyValidatorFields is BaseBeaconChainProofTest {
    bytes32 validatorListRoot;
    bytes32[][] validatorFields;
    bytes32[] proof;
    uint40[] validatorIndices;

    function setUp() override public {
        super.setUp();
        string memory filePath = "./src/test/test-data/ValidatorFields-proof.json";
        parser.setJSONPath(filePath);

        validatorListRoot = parser.getValidatorListRoot();
        validatorIndices = parser.getValidatorIndices();
        validatorFields = parser.getValidatorFields(validatorIndices.length);
        proof = parser.getValidatorFieldsProof();
    }

    function test_CanVerifyValidatorFieldsProof() external view {
        beaconChainProofHarness.verifyValidatorFields(
            validatorListRoot,
            validatorFields,
            proof,
            validatorIndices
        );
    }

    function test_CannotVerifyInvalidProof() external {
        proof[0] = 0x0000000000000000000000000000000000000000000000000000000000000001;

        vm.expectRevert(BeaconChainProofs.BeaconChainProofs__InvalidValidatorFieldsMerkleProof.selector);
        beaconChainProofHarness.verifyValidatorFields(
            validatorListRoot,
            validatorFields,
            proof,
            validatorIndices
        );
    }
}


contract BeaconChainProofTest__VerifyValidatorBalance is BaseBeaconChainProofTest {
    bytes32 balanceListRoot;
    bytes32[] proof;
    bytes32[] validatorBalances;
    uint40[] validatorIndices;

    function setUp() override public {
        super.setUp();
        string memory filePath = "./src/test/test-data/ValidatorBalance-proof.json";
        parser.setJSONPath(filePath);

        proof = parser.getValidatorBalancesProof();
        balanceListRoot = parser.getBalanceListRoot();
        validatorIndices = parser.getValidatorIndices();
        validatorBalances = parser.getValidatorBalancesRoot();
    }

    function test_CanVerifyCorrectProof() external view {
        beaconChainProofHarness.verifyValidatorBalancesProof(
            balanceListRoot,
            proof,
            validatorIndices,
            validatorBalances
        );
    }

    function test_CannotVerifyCorrectIncorrectProof() external {
        proof[0] = 0x0000000000000000000000000000000000000000000000000000000000000001;
         vm.expectRevert(BeaconChainProofs.BeaconChainProofs__InvalidValidatorFieldsMerkleProof.selector);
        beaconChainProofHarness.verifyValidatorBalancesProof(
            balanceListRoot,
            proof,
            validatorIndices,
            validatorBalances
        );
    }
}


