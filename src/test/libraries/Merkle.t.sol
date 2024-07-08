// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;
import "forge-std/Test.sol";
import {Merkle} from "src/libraries/Merkle.sol";

contract MerkleTest is Test {

    function setUp() public {

    }

    function hashNodes(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(left, right));
    }

    function testVerifyCorrectMultiProof() public {
        console.logBytes32(bytes32(uint256(1) << 0xf));

        // bytes32[] memory leaves = new bytes32[](4);
        // leaves[0] = keccak256(abi.encodePacked("leaf1"));
        // leaves[1] = keccak256(abi.encodePacked("leaf2"));
        // leaves[2] = keccak256(abi.encodePacked("leaf3"));
        // leaves[3] = keccak256(abi.encodePacked("leaf4"));

        // // show(leaves);

        // bytes32[] memory layer1 = new bytes32[](2);
        // layer1[0] = hashNodes(leaves[0], leaves[1]);
        // layer1[1] = hashNodes(leaves[2], leaves[3]);


        // // show(layer1);

        // bytes32 root = hashNodes(layer1[0], layer1[1]);

        // uint256 index1 = 1;
        // uint256 index2 = 3;

        // uint256[] memory indices = new uint256[](2);
        // indices[0] = index1;
        // // indices[1] = index2;

        // bytes32[] memory leavesToprove = new bytes32[](2);
        // leavesToprove[0] = leaves[index1];
        // // leavesToprove[1] = leaves[index2];

        // bytes32[] memory proof = new bytes32[](2);
        // proof[0] = leaves[0];
        // proof[1] = leaves[2];


        // Merkle.Node[] memory nodes = new Merkle.Node[](2);
        // nodes[0] = Merkle.Node(leavesToprove[0], indices[0]);
        // nodes[1] = Merkle.Node(leavesToprove[1], indices[1]);


        // bool success = Merkle.verifyMultiProofInclusionSha256(
        //     root,
        //     proof,
        //     nodes,
        //     2
        // );

        // console.log(success);
        // assertTrue(success);
    }

    // function testVerifyCorrectMultiProof10() public {
    //     bytes32[] memory leaves = new bytes32[](10);
    //     leaves[0] = keccak256(abi.encodePacked("leaf1"));
    //     leaves[1] = keccak256(abi.encodePacked("leaf2"));
    //     leaves[2] = keccak256(abi.encodePacked("leaf3"));
    //     leaves[3] = keccak256(abi.encodePacked("leaf4"));
    //     leaves[4] = keccak256(abi.encodePacked("leaf5"));
    //     leaves[5] = keccak256(abi.encodePacked("leaf6"));
    //     leaves[6] = keccak256(abi.encodePacked("leaf7"));
    //     leaves[7] = keccak256(abi.encodePacked("leaf8"));
    //     leaves[8] = keccak256(abi.encodePacked("leaf9"));
    //     leaves[9] = keccak256(abi.encodePacked("leaf0"));

    //     // show(leaves);

    //     bytes32[] memory layer1 = new bytes32[](2);
    //     layer1[0] = hashNodes(leaves[0], leaves[1]);
    //     layer1[1] = hashNodes(leaves[2], leaves[3]);

    //     // // show(layer1);

    //     bytes32 root = hashNodes(layer1[0], layer1[1]);

    //     uint256[] memory indices = new uint256[](2);
    //     indices[0] = 1;
    //     indices[1] = 2;

    //     bytes32[] memory leavesToprove = new bytes32[](2);
    //     leavesToprove[0] = leaves[1];
    //     leavesToprove[1] = leaves[2];

    //     bytes32[] memory proof = new bytes32[](2);
    //     proof[0] = leaves[0];
    //     proof[1] = leaves[3];


    //     Merkle.Node[] memory nodes = new Merkle.Node[](2);
    //     nodes[0] = Merkle.Node(leavesToprove[0], indices[0]);
    //     nodes[1] = Merkle.Node(leavesToprove[1], indices[1]);


    //     bool success = Merkle.verifyMultiProofInclusionSha256(
    //         root,
    //         proof,
    //         nodes,
    //         2
    //     );

    //     console.log(success);
    //     // assertTrue(success);
    // }

    function show(bytes32[] memory values) internal view {
        string memory logger;

        for (uint i = 0; i < values.length; i++) {
            // string memory val = string(bytes(values[i]));
            // logger = string.concat(logger, string.concat(" ", val));
        }
        console.log(logger);
    }
    
}