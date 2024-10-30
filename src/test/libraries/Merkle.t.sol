// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;
import "forge-std/Test.sol";
import {Merkle} from "src/libraries/Merkle.sol";
import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";

contract MerkleHarness {
    function verifyMultiProofInclusionSha256(
        bytes32 expectedRoot,
        bytes32[] calldata proof,
        Merkle.Node[] memory leaves,
        uint256 numLayers
    ) external view returns (bool) {
        return Merkle.verifyMultiProofInclusionSha256({
            expectedRoot: expectedRoot,
            proof: proof,
            leaves: leaves,
            numLayers: numLayers
        });
    }
}

contract MerkleTest is Test {
    MerkleHarness merkleHarness;

    function setUp() public {
        merkleHarness = new MerkleHarness();
    }

    function hashNodes(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(left, right));
    }

    function testVerifyCorrectMultiProof() external {
        bytes32[] memory leaves = new bytes32[](4);
        leaves[0] = keccak256(abi.encodePacked("leaf1"));
        leaves[1] = keccak256(abi.encodePacked("leaf2"));
        leaves[2] = keccak256(abi.encodePacked("leaf3"));
        leaves[3] = keccak256(abi.encodePacked("leaf4"));

        bytes32[] memory layer1 = new bytes32[](2);
        layer1[0] = hashNodes(leaves[0], leaves[1]);
        layer1[1] = hashNodes(leaves[2], leaves[3]);

        bytes32 root = hashNodes(layer1[0], layer1[1]);

        uint256 index1 = 1;
        uint256 index2 = 3;

        uint256[] memory indices = new uint256[](2);
        indices[0] = index1;
        indices[1] = index2;

        bytes32[] memory leavesToprove = new bytes32[](2);
        leavesToprove[0] = leaves[index1];
        leavesToprove[1] = leaves[index2];

        bytes32[] memory proof = new bytes32[](2);
        proof[0] = leaves[0];
        proof[1] = leaves[2];


        Merkle.Node[] memory nodes = new Merkle.Node[](2);
        nodes[0] = Merkle.Node(leavesToprove[0], indices[0]);
        nodes[1] = Merkle.Node(leavesToprove[1], indices[1]);


        bool success = merkleHarness.verifyMultiProofInclusionSha256(
            root,
            proof,
            nodes,
            2
        );

        assertTrue(success);
    }
}