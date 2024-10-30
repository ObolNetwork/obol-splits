// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {BeaconChainProofs, Merkle} from "src/libraries/BeaconChainProof.sol";
import {BaseSymPodHarnessTest, ISymPod} from "../SymPod.t.sol";
import "forge-std/Test.sol";

contract SymPodHandler is Test {
  function setUp() public {}

//   function test_Assembly() external {
//     uint256[] memory array = new uint256[](10);
//     array[0] = 1;

//     uint256 sizeOfArray;

//     assembly ("memory-safe") {
//       sizeOfArray := mload(array)
//     }

//     console.log(sizeOfArray);
//   }

//   function test_Sha256() external {
//     Merkle.Node[] memory array = new Merkle.Node[](8);

//     array[0] = Merkle.Node(bytes32(uint256(10)), 10);
//     array[1] = Merkle.Node(bytes32(uint256(9)), 9);
//     array[2] = Merkle.Node(bytes32(uint256(8)), 8);
//     array[3] = Merkle.Node(bytes32(uint256(7)), 7);
//     array[4] = Merkle.Node(bytes32(uint256(6)), 6);
//     array[5] = Merkle.Node(bytes32(uint256(6)), 5);
//     array[6] = Merkle.Node(bytes32(uint256(4)), 4);
//     array[7] = Merkle.Node(bytes32(uint256(3)), 3);

//     uint256 gasBefore = gasleft();
//     array = Merkle.sort(array);
//     uint256 gasAfter = gasleft();

//     console.log("===========================");
//     console.log(gasBefore);
//     console.log(gasAfter);
//     console.log(gasBefore - gasAfter);
//     console.log("===========================");

//     // uint256 b = 2;
//     console.log(array[0].index);
//     console.logBytes32(array[0].leaf);
//     console.log(array[1].index);
//     console.logBytes32(array[1].leaf);
//     console.log(array[2].index);
//     console.logBytes32(array[2].leaf);
//     console.log(array[3].index);
//     console.logBytes32(array[3].leaf);
//     console.log(array[4].index);
//     console.logBytes32(array[4].leaf);
//     console.log(array[5].index);
//     console.logBytes32(array[5].leaf);
//     console.log(array[6].index);
//     console.logBytes32(array[6].leaf);
//     console.log(array[7].index);
//     console.logBytes32(array[7].leaf);

//     (Merkle.Node memory item, bool found) = Merkle.contains(array, 3);
//     console.log("contains");
//     console.logBool(found);
//     console.logBytes32(item.leaf);
//     console.log(item.index);

//     // console.logBytes32(sha256(abi.encodePacked(a,b)));
//     // console.logBytes32(Merkle.efficientSha256(a, b)[0]);
//     // assertEq(
//     //     sha256(abi.encodePacked(a,b)),
//     //     Merkle.efficientSha256(a, b)[0],
//     //     "not eqaul"
//     // );
//   }
}
