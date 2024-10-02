// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import {stdJson} from "forge-std/Test.sol";
import "forge-std/Test.sol";
import { BeaconChainProofs } from "src/libraries/BeaconChainProof.sol";

contract SymPodProofParser is Test {
    using stdJson for string;

    string public proofPath;

    function setJSONPath(string memory proofJsonPath) public {
        proofPath = vm.readFile(proofJsonPath);
    }

    function getBlockRoot() public returns (bytes32) {
        return vm.parseJsonBytes32(proofPath, ".blockRoot");
    }

    function getValidatorListRoot() public returns (bytes32) {
        return vm.parseJsonBytes32(proofPath, ".validatorListRoot");
    }

    function getBalanceListRoot() public returns (bytes32) {
        return vm.parseJsonBytes32(proofPath, ".balanceListRoot");
    }

    function getVBListRootAgainstBlockRootProof() public returns (bytes32[] memory) {
        return vm.parseJsonBytes32Array(proofPath, ".VBListRootAgainstBlockRootProof");
    }

    function getValidatorBalancesRoot() public returns (bytes32[] memory) {
       return vm.parseJsonBytes32Array(proofPath, ".validatorBalancesRoot");
    }

    function getValiatorIndices() public returns (uint40[] memory) {
        uint256[] memory validatorIndices = vm.parseJsonUintArray(proofPath, ".validatorIndices");

        uint40[] memory indices = new uint40[](validatorIndices.length);
        for(uint256 i = 0; i < validatorIndices.length; i++) {
            indices[i] = uint40(validatorIndices[i]);
        }
        return indices;
    }

    function getValidatorBalancesProof() public returns (bytes32[] memory) {
        return vm.parseJsonBytes32Array(proofPath, ".ValidatorBalancesAgainstBalanceRootProof");
    }

    function getValidatorFields(uint256 size) public returns(bytes32[][] memory validatorFields) {
        validatorFields = new bytes32[][](size);

        for(uint256 j = 0; j < size; j++) {
            bytes32[] memory validatorField = new bytes32[](8);
            string memory base = string.concat(".validatorFields[", string.concat(vm.toString(j), "]"));

            for (uint256 i = 0; i < 8; i++) {
                string memory prefix = string.concat(base, "[", string.concat(vm.toString(i), "]"));
                validatorField[i] = vm.parseJsonBytes32(proofPath, prefix); 
            }
            validatorFields[j] = validatorField;
        }

        return validatorFields;
    }

    function getValidatorFieldsProof() public returns (bytes32[] memory) {
        return vm.parseJsonBytes32Array(proofPath, ".ValidatorFieldsAgainstValidatorListProof");
    }
    
}