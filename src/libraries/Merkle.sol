// SPDX-License-Identifier: GPL-3.0-or-later
// Modified from OpenZeppelin Contracts (last updated v4.8.0) (utils/cryptography/MerkleProof.sol)

pragma solidity ^0.8.0;

/**
 * @dev These functions deal with verification of Merkle Tree proofs.
 *
 * The tree and the proofs can be generated using our
 * https://github.com/OpenZeppelin/merkle-tree[JavaScript library].
 * You will find a quickstart guide in the readme.
 *
 * WARNING: You should avoid using leaf values that are 64 bytes long prior to
 * hashing, or use a hash function other than keccak256 for hashing leaves.
 * This is because the concatenation of a sorted pair of internal nodes in
 * the merkle tree could be reinterpreted as a leaf value.
 * OpenZeppelin's JavaScript library generates merkle trees that are safe
 * against this attack out of the box.
 */
library Merkle {

    struct Node {
        bytes32 leaf;
        uint256 index;
    }

    /// @dev Indices should be sorted from lowest to highest
    error Merkle__IndicesOutOfOrder();
    /// @dev Proof Length should be a non-zero multiple of 32
    error Merkle__IncorrectProofLength();
    error Merkle__MismatchLeavesAndIndices();
    error Merkle__InsufficientProofElements();
    error Merkle__RootNotConstructed();


    function verifyMultiProofInclusionSha256(
        bytes32 expectedRoot,
        bytes32[] calldata proof,
        Node[] memory leaves,
        uint256 numLayers
    ) internal pure returns (bool) {
        return processMultiInclusionProofSha256(proof, leaves, numLayers) == expectedRoot;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. The tree is built assuming `leaf` is
     * the 0 indexed `index`'th leaf from the bottom left of the tree.
     *
     * Note this is for a Merkle tree using the sha256 hash function
     */
    function verifyInclusionSha256(
        bytes memory proof,
        bytes32 root,
        bytes32 leaf,
        uint256 index
    ) internal view returns (bool) {
        return processInclusionProofSha256(proof, leaf, index) == root;
    }
    
    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. The tree is built assuming `leaf` is
     * the 0 indexed `index`'th leaf from the bottom left of the tree.
     *
     * _Available since v4.4._
     *
     * Note this is for a Merkle tree using the sha256 hash function
     */
    function processInclusionProofSha256(
        bytes memory proof,
        bytes32 leaf,
        uint256 index
    ) internal view returns (bytes32) {
        require(
            proof.length != 0 && proof.length % 32 == 0,
            "Merkle.processInclusionProofSha256: proof length should be a non-zero multiple of 32"
        );
        bytes32[1] memory computedHash = [leaf];
        for (uint256 i = 32; i <= proof.length; i += 32) {
            if (index % 2 == 0) {
                // if ith bit of index is 0, then computedHash is a left sibling
                assembly {
                    mstore(0x00, mload(computedHash))
                    mstore(0x20, mload(add(proof, i)))
                    if iszero(staticcall(sub(gas(), 2000), 2, 0x00, 0x40, computedHash, 0x20)) { revert(0, 0) }
                    index := div(index, 2)
                }
            } else {
                // if ith bit of index is 1, then computedHash is a right sibling
                assembly {
                    mstore(0x00, mload(add(proof, i)))
                    mstore(0x20, mload(computedHash))
                    if iszero(staticcall(sub(gas(), 2000), 2, 0x00, 0x40, computedHash, 0x20)) { revert(0, 0) }
                    index := div(index, 2)
                }
            }
        }
        return computedHash[0];
    }

     /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `multiproof`. A `multiproof` is valid if and only if the rebuilt
     * hash matches the root of the tree. The tree is built assuming `leaf` is
     * the 0 indexed `index`'th leaf from the bottom left of the tree.
     *
     *
     *
     * Note this is for a Merkle tree using the sha256 hash function
     */
    function processMultiInclusionProofSha256(
        bytes32[] calldata proof,
        Node[] memory leaves,
        uint256 numLayers
    ) internal pure returns (bytes32 ) {
        uint256 proofIndex = 0;
        Node[] memory currentLayer = sort(leaves);
        // Process each layer
        for (uint256 l = 0; l < numLayers; l++) {
            Node[] memory nextLayer = new Node[](0);

            for (uint256 i = 0; i < currentLayer.length; i++) {
                Node memory currentLeaf = currentLayer[i];
                bytes32 siblingLeaf;
                {
                    uint256 siblingIndex = currentLeaf.index ^ 1;
                    (Node memory value, bool foundNode) = contains(currentLayer, siblingIndex);

                    if (foundNode == true) {
                        siblingLeaf = value.leaf;
                    } else if (proofIndex < proof.length) {
                        siblingLeaf = proof[proofIndex];
                        proofIndex += 1;
                    } else {
                        revert Merkle__InsufficientProofElements();
                    }
                }

                bytes32 parentLeaf;
                if (currentLeaf.index & 1 == 0) {
                    parentLeaf = sha256(abi.encodePacked(currentLeaf.leaf, siblingLeaf));
                } else {
                    parentLeaf = sha256(abi.encodePacked(siblingLeaf, currentLeaf.leaf));
                }

                uint256 nextIndex = currentLeaf.index >> 1;
                (, bool found) = contains(nextLayer, nextIndex);
                

                if (found == false) {
                    nextLayer = append(nextLayer, Node(parentLeaf, nextIndex));
                }
            }

            currentLayer = sort(nextLayer);
        }

        Node memory root = currentLayer[0];
        if (root.leaf == bytes32(0) || currentLayer.length > 1) {
            revert Merkle__RootNotConstructed();
        }

        return root.leaf;
    }

    function contains(Node[] memory leaves, uint256 index) internal pure returns (Node memory value, bool found) {
        if (leaves.length == 0) {
            return (value, false);
        }
        
        for (uint256 i = 0; i < leaves.length; i++ ) {
            if (leaves[i].index == index) {
                return (leaves[i], true);
            }
        }

        return (value, false);
    }

    function append(Node[] memory values, Node memory insert ) internal pure returns (Node[] memory merged) {
        uint256 baseLength = values.length;

        if (baseLength == 0) {
            merged =  new Node[](1);
            merged[0] = insert;
            return merged;
        }


        uint256 size = baseLength + 1;
        merged = new Node[](size);

        for (uint256 i = 0; i < size; i++) {
            if (i == baseLength) {
                merged[i] = insert;
            } else {
                merged[i] = values[i];
            }
        }
    }

    /**
     @notice this function returns the merkle root of a tree created from a set of leaves using sha256 as its hash function
     @param leaves the leaves of the merkle tree
     @return The computed Merkle root of the tree.
     @dev A pre-condition to this function is that leaves.length is a power of two.  If not, the function will merkleize the inputs incorrectly.
     */
    function merkleizeSha256(bytes32[] memory leaves) internal pure returns (bytes32) {
        //there are half as many nodes in the layer above the leaves
        uint256 numNodesInLayer = leaves.length / 2;
        //create a layer to store the internal nodes
        bytes32[] memory layer = new bytes32[](numNodesInLayer);
        //fill the layer with the pairwise hashes of the leaves
        for (uint256 i = 0; i < numNodesInLayer; i++) {
            layer[i] = sha256(abi.encodePacked(leaves[2 * i], leaves[2 * i + 1]));
        }
        //the next layer above has half as many nodes
        numNodesInLayer /= 2;
        //while we haven't computed the root
        while (numNodesInLayer != 0) {
            //overwrite the first numNodesInLayer nodes in layer with the pairwise hashes of their children
            for (uint256 i = 0; i < numNodesInLayer; i++) {
                layer[i] = sha256(abi.encodePacked(layer[2 * i], layer[2 * i + 1]));
            }
            //the next layer above has half as many nodes
            numNodesInLayer /= 2;
        }
        //the first node in the layer is the root
        return layer[0];
    }

    /// @notice Insertion sort node
    function sort(Node[] memory myArray)
        internal
        pure
        returns (Node[] memory)
    {

        uint256 n = myArray.length;

        if (n == 1) {
            return myArray;
        }

        if (n == 2) {
            if (myArray[0].index < myArray[1].index) {
                return myArray;
            } else {
                Node memory temp = myArray[0];
                myArray[0] = myArray[1];
                myArray[1] = temp;
                return myArray;
            }
        }

        for (uint256 i = 1; i < n; i++) {
            uint256 key = myArray[i].index;
            int256 j = int256(i - 1);

            while (j >= 0 && int256(myArray[uint256(j)].index ) > int256(key)) {
                myArray[uint256(j + 1)] = myArray[uint256(j)];
                j--;
            }

            myArray[uint256(j + 1)] = myArray[i];
        }

        return myArray;
    }

}
