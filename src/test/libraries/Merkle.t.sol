// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;
import "forge-std/Test.sol";
import {Merkle} from "src/libraries/Merkle.sol";
import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";

contract MerkleTest is Test {

    function setUp() public {

    }

    function hashNodes(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(left, right));
    }

    function testVerifyCorrectMultiProof() public {
        // console.logBytes32(bytes32(uint256(1) << 0xf));

        bytes32[] memory leaves = new bytes32[](4);
        leaves[0] = keccak256(abi.encodePacked("leaf1"));
        leaves[1] = keccak256(abi.encodePacked("leaf2"));
        leaves[2] = keccak256(abi.encodePacked("leaf3"));
        leaves[3] = keccak256(abi.encodePacked("leaf4"));

        // show(leaves);

        bytes32[] memory layer1 = new bytes32[](2);
        layer1[0] = hashNodes(leaves[0], leaves[1]);
        layer1[1] = hashNodes(leaves[2], leaves[3]);


        // show(layer1);

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


        bool success = Merkle.verifyMultiProofInclusionSha256(
            root,
            proof,
            nodes,
            2
        );

        assertTrue(success);
    }

    function testVerifyCorrectMultiProof2() public {
        bytes32[] memory multiProof = new bytes32[](9);
        multiProof[0] = 0x7844070000000000000000000000000000000000000000000000000000000000;
        multiProof[1] = 0x1e50a93f0eb7c3849d16b49b737853cb99f5555a2964f05b20f29c36b16aec5b;
        multiProof[2] = 0xa1078446f835350e063b8a3b33f8c0fd6c43c5c1fac0839ce41af13c0e4a6221;
        multiProof[3] = 0x7afe7a1c2681493fdde4394c8f446b60944225c77156f2833b5ac21b77ce155b;
        multiProof[4] = 0xf7cf88e9755e66820fb52b8622a3c03ce1a0394f46101594fdad376e4f3d3750;
        multiProof[5] = 0x44c86ede901137e5c3021380383908a0b3b6c00d6e451bcae139a74b0ae39e65;
        multiProof[6] = 0x44c7dd0a84a62964cdf05a04d5f948be4dbf91919c6cbcb0ec819117e2f904dd;
        multiProof[7] = 0xad6c55602effb4d13c7df3472814008cdee357514c5a810f3c83e4f14778510e;
        multiProof[8] = 0x0634c4e39d1f68e3229b07c8cf7c8899b1fee76c880426b444309f95d03498ed;

        BeaconChainProofs.verifyValidatorRootAndBalanceRootAgainstBlockRoot(
            0x92d898cb189bae13cb97db2818ec1426dc1ce9047f1d184790eca8d0a4995135,
            0x8282a75c0380ec4740a8ab21e071f8fec4124480c0872e056b41f96390d13a11,
            0x28951909fca04e642a8cb6fda53de5f2b7d0239beb8c7891ca0122093adc6378,
            multiProof
        );

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