// // SPDX-License-Identifier: GPL-3.0-or-later
// pragma solidity 0.8.19;
// import {stdJson} from "forge-std/Test.sol";
// import "forge-std/Test.sol";
// import { BeaconChainProofs } from "src/libraries/BeaconChainProof.sol";

// contract ProofParser is Test {
//     using stdJson for string;

//     string public proofPath;

//     function setJSONPath(string memory proofJsonPath) public {
//         proofPath = vm.readFile(proofJsonPath);
//     }

//     function getBlockRoot() public returns (bytes32) {
//         return vm.parseJsonBytes32(proofPath, ".blockRoot");
//     }

//     function getValidatorListRoot() public returns (bytes32) {
//         return vm.parseJsonBytes32(proofPath, ".validatorListRoot");
//     }

//     function getBalanceListRoot() public returns (bytes32) {
//         return vm.parseJsonBytes32(proofPath, ".balanceListRoot");
//     }

//     function getVBListRootAgainstBlockRootProof() public returns (bytes32) {
//         return vm.parseJsonBytes32(proofPath, ".VBListRootAgainstBlockRootProof");
//     }
//     // function getSlot() public returns (uint256) {
//     //    return vm.parseJsonUint(proofPath, ".slot");
//     // }

//     // function getValidatorIndex() public returns (uint256) {
//     //     return vm.parseJsonUint(proofPath, ".validatorIndex");
//     // }

//     // function getHistoricalSummaryIndex() public returns (uint256) {
//     //     return vm.parseJsonUint(proofPath, ".historicalSummaryIndex");
//     // }

//     // function getWithdrawalIndex() public returns (uint256) {
//     //     return vm.parseJsonUint(proofPath, ".withdrawalIndex");
//     // }

//     // function getBlockHeaderRootIndex() public returns (uint256) {
//     //     return vm.parseJsonUint(proofPath, ".blockHeaderRootIndex");
//     // }

//     // function getBeaconStateRoot() public returns (bytes32) {
//     //     return vm.parseJsonBytes32(proofPath, ".beaconStateRoot");
//     // }

//     // function getSlotRoot() public returns (bytes32) {
//     //     return vm.parseJsonBytes32(proofPath, ".slotRoot");
//     // }

//     // function getTimestampRoot() public returns (bytes32) {
//     //     return vm.parseJsonBytes32(proofPath, ".timestampRoot");
//     // }

//     // function getBlockHeaderRoot() public returns (bytes32) {
//     //     return vm.parseJsonBytes32(proofPath, ".blockHeaderRoot");
//     // }

//     // function getExecutionPayloadRoot() public returns (bytes32) {
//     //     return vm.parseJsonBytes32(proofPath, ".executionPayloadRoot");
//     // }

//     // function getLatestBlockHeaderRoot() public returns (bytes32) {
//     //     return vm.parseJsonBytes32(proofPath, ".latestBlockHeaderRoot");
//     // }

//     // function getSlotProof() public returns (bytes32[] memory) {
//     //     return vm.parseJsonBytes32Array(proofPath, ".SlotProof");
//     // }

//     // function getWithdrawalProof() public returns (bytes32[] memory) {
//     //     return vm.parseJsonBytes32Array(proofPath, ".WithdrawalProof");
//     // }

//     // function getValidatorProof() public returns (bytes32[] memory) {
//     //     return vm.parseJsonBytes32Array(proofPath, ".ValidatorProof");
//     // }
    
//     // function getTimestampProof() public returns (bytes32[] memory) {
//     //     return vm.parseJsonBytes32Array(proofPath, ".TimestampProof");
//     // }

//     // function getExecutionPayloadProof() public returns (bytes32[] memory) {
//     //     return vm.parseJsonBytes32Array(proofPath, ".ExecutionPayloadProof");
//     // }

//     // function getValidatorFields() public returns (bytes32[] memory) {
//     //     return vm.parseJsonBytes32Array(proofPath, ".ValidatorFields");
//     // }

//     // function getWithdrawalFields() public returns (bytes32[] memory) {
//     //     return vm.parseJsonBytes32Array(proofPath, ".WithdrawalFields");
//     // }

//     // function getStateRootAgainstLatestBlockHeaderProof() public returns (bytes32[] memory) {
//     //     return vm.parseJsonBytes32Array(proofPath, ".StateRootAgainstLatestBlockHeaderProof");
//     // }

//     // function getHistoricalSummaryProof() public returns (bytes32[] memory) {
//     //     return vm.parseJsonBytes32Array(proofPath, ".HistoricalSummaryProof");
//     // }

//     // function values() public returns (
//     //     BeaconChainProofs.StateRootProof memory stateRootProof,
//     //     BeaconChainProofs.WithdrawalProof memory withdrawalProof,
//     //     bytes memory validatorFieldsProof,
//     //     bytes32[] memory validatorFields,
//     //     bytes32[] memory withdrawalFields
//     // ) {
//     //     stateRootProof = BeaconChainProofs.StateRootProof({
//     //         beaconStateRoot: getBeaconStateRoot(),
//     //         proof: abi.encodePacked(getStateRootAgainstLatestBlockHeaderProof())
//     //     });

//     //     withdrawalProof = BeaconChainProofs.WithdrawalProof({
//     //         withdrawalProof: abi.encodePacked(getWithdrawalProof()),
//     //         slotProof: abi.encodePacked(getSlotProof()),
//     //         executionPayloadProof: abi.encodePacked(getExecutionPayloadProof()),
//     //         timestampProof: abi.encodePacked(getTimestampProof()),
//     //         historicalSummaryBlockRootProof: abi.encodePacked(getHistoricalSummaryProof()),
//     //         blockRootIndex: uint64(getBlockHeaderRootIndex()),
//     //         historicalSummaryIndex: uint64(getHistoricalSummaryIndex()),
//     //         withdrawalIndex: uint64(getWithdrawalIndex()),
//     //         blockRoot: getBlockHeaderRoot(),
//     //         slotRoot: getSlotRoot(),
//     //         timestampRoot: getTimestampRoot(),
//     //         executionPayloadRoot: getExecutionPayloadRoot()
//     //     });

//     //     validatorFieldsProof = abi.encodePacked(getValidatorProof());
//     //     validatorFields = getValidatorFields();
//     //     withdrawalFields =  getWithdrawalFields();
//     // }

//     // function encodeToCapsuleParam() public returns (bytes memory encodedProof) {
//     //     (
//     //         BeaconChainProofs.StateRootProof memory stateRootProof,
//     //         BeaconChainProofs.WithdrawalProof memory withdrawalProof,
//     //         bytes memory validatorFieldsProof,
//     //         bytes32[] memory validatorFields,
//     //         bytes32[] memory withdrawalFields
//     //     ) = values();

//     //     return abi.encode(
//     //         stateRootProof,
//     //         withdrawalProof,
//     //         validatorFieldsProof,
//     //         validatorFields,
//     //         withdrawalFields
//     //     );

//     // }
// }