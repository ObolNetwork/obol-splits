// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./Merkle.sol";
import "../libraries/Endian.sol";

// Library for verifying ETH consensus layer proofs
// Consensus Specs https://github.com/ethereum/consensus-specs/
library BeaconChainProofs {

    error BeaconChainProofs__InvalidValidatorRootandBalanceRootProof();
    error BeaconChainProofs__InvalidProofSize();
    error BeaconChainProofs__InvalidMerkleProof();
    error BeaconChainProofs__InvalidValidatorField(uint256 index);
    error BeaconChainProofs__InvalidIndicesAndFields(uint256 indexSize, uint256 fieldSize);
    error BeaconChainProofs__InvalidValidatorFieldsMerkleProof();
    error BeaconChainProofs__InvalidIndicesAndBalances();
    error BeaconChainProofs__IncorrectWithdrawalCredentials(bytes32 pubkeyHash);
    error BeaconChainProofs__InvalidValidatorRootProof();
    error BeaconChainProofs__InvalidBalanceRootProof();
    error BeaconChainProofs__InvalidInputLength();
    
    /// @dev BeaconBlockHeader Spec: https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#beaconblockheader
    uint256 internal constant BEACON_BLOCK_HEADER_FIELD_TREE_HEIGHT = 3;
    /// @dev BeaconState Spec:  https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#beaconstate
    uint256 internal constant BEACON_STATE_TREE_HEIGHT = 5;
    uint256 internal constant BALANCE_TREE_HEIGHT = 38;
    uint256 internal constant NUM_VALIDATOR_FIELDS = 8;
    uint256 internal constant VALIDATOR_FIELD_TREE_HEIGHT = 3;
    uint256 internal constant VALIDATOR_TREE_HEIGHT = 40;
    /// @notice Number of fields in the `Validator` container
    /// (See https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#validator)
    uint256 internal constant VALIDATOR_FIELDS_LENGTH = 8;
    // in beacon block header https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#beaconblockheader
    uint256 internal constant STATE_ROOT_INDEX = 3;
    //  in beacon state https://github.com/ethereum/consensus-specs/blob/dev/specs/capella/beacon-chain.md#beaconstate
    uint256 internal constant VALIDATOR_LIST_INDEX = 11;
    uint256 internal constant BALANCE_LIST_ROOT_INDEX = 12;
    // in validator https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#validator
    uint256 internal constant VALIDATOR_PUBKEY_INDEX = 0;
    uint256 internal constant VALIDATOR_WITHDRAWAL_CREDENTIALS_INDEX = 1;
    uint256 internal constant VALIDATOR_BALANCE_INDEX = 2;
    uint256 internal constant VALIDATOR_SLASHED_INDEX = 3;
    uint256 internal constant VALIDATOR_ACTIVATION_EPOCH_INDEX = 5;
    uint256 internal constant VALIDATOR_EXIT_EPOCH_INDEX = 6;
    uint256 internal constant VALIDATOR_WITHDRAWABLE_EPOCH_INDEX = 7;
    /// @notice Exit epoch for non-exited validators and activation epoch for exited validators
    /// @dev https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md?plain=1#L185
    uint256 internal constant FAR_FUTURE_EPOCH = (2**64) - 1;

    /// @notice Validator fields and it proof against the validator registry
    struct ValidatorProof {
        bytes32[] validatorFields;
        bytes proof;
        uint40 validatorIndex;
    }

    /// @notice Struct for verifying multiple validator fields against validator registry 
    struct ValidatorsMultiProof {
        bytes32[][] validatorFields;
        bytes32[] proof;
        uint40[] validatorIndices;
    }

    /// @notice Struct for verifying BeaconState balance registry against beacon block root
    struct BalanceRegistryProof {
        bytes32 balanceListRoot;
        bytes proof;
    }

    /// @notice Struct for verify BeaconState validator regsitry against Beacon block root
    struct ValidatorRegistryProof {
        bytes32 validatorListRoot;
        bytes proof;
    }

    struct BalancesMultiProof {
        bytes32[] proof;
        bytes32[] validatorPubKeyHashes;
        bytes32[] validatorBalanceRoots;
    }

    struct BalanceProof {
        bytes proof;
        bytes32 validatorPubKeyHash;
        bytes32 validatorBalanceRoot;
    }

    /// @notice Verify a merkle proof a validator field against the beacon state validatorListRoot
    /// @param validatorListRoot the merkle root of all validator fields 
    /// @param validatorFields validator fields
    /// @param validatorFieldsProof merkle proof of validator fields against validatorListRoot
    /// @param validatorIndex index of the validator being proven
    function verifyValidatorFields(
        bytes32 validatorListRoot,
        bytes32[] calldata validatorFields,
        bytes calldata validatorFieldsProof,
        uint40 validatorIndex
    ) internal view {
        if (validatorFields.length != (2 ** VALIDATOR_FIELD_TREE_HEIGHT)) {
            revert BeaconChainProofs__InvalidValidatorField(0);
        }

        /// NB: We use `VALIDATOR_TREE_HEIGHT + 1` here because the merkle tree of the 
        /// validator list registry includes hashing the root of the validator tree 
        /// with the length of the validator list
        if (validatorFieldsProof.length != (32 * (VALIDATOR_TREE_HEIGHT + 1))) {
            revert BeaconChainProofs__InvalidProofSize();
        } 

        bytes32 validatorRoot = Merkle.merkleizeSha256(validatorFields);

        if(
            Merkle.verifyInclusionSha256({
                proof: validatorFieldsProof,
                root: validatorListRoot,
                leaf: validatorRoot,
                index: validatorIndex
            }) == false
        ) {
            revert BeaconChainProofs__InvalidMerkleProof();
        }
    }

    /// @notice Verify a merkle proof of a validator's balance against the BeaconState balance registry list
    /// @param balanceListRoot the merkle root of the BeaconState balance registry
    /// @param validatorIndex the index of the validator whose balance we are proving
    /// @param proof Contains the validator's balance root and a merkle proof against `balanceListRoot`
    function verifyValidatorBalance(
        bytes32 balanceListRoot,
        uint40 validatorIndex,
        BalanceProof calldata proof
    ) internal view {
        /// NB: We use `BALANCE_TREE_HEIGHT + 1` because the merkle tree of the balance
        /// registry list includes hashing the root of the balances tree with the length 
        /// of the balance registry list
        if (proof.proof.length != 32 * (BALANCE_TREE_HEIGHT + 1)) {
            revert BeaconChainProofs__InvalidProofSize();
        }
        /// When merkleized, beacon chain balances are combined into groups of 4 called a `balanceRoot`. The merkle
        /// proof here verifies that this validator's `balanceRoot` is included in the `balanceContainerRoot`
        /// balanceListRoot HEIGHT: BALANCE_TREE_HEIGHT
        /// /\              
        /// balanceRoot
        uint256 balanceIndex = uint256(validatorIndex / 4);

        if(
            Merkle.verifyInclusionSha256({
                proof: proof.proof,
                root: balanceListRoot,
                leaf: proof.validatorBalanceRoot,
                index: balanceIndex
            }) == false
            ) 
        {
            revert BeaconChainProofs__InvalidMerkleProof();
        }
    }
    
    /// @notice Verify merkle multiproof of multiple validator fields against the `validatorListRoot`
    /// @param validatorListRoot is the validator list root to be proven against.
    /// @param validatorFields the fields of the multiple validators being provien
    /// @param validatorIndices the sorted indices of the validators being proven
    /// @param proof is the data used in proving the validator's fields
    function verifyMultipleValidatorFields(
        bytes32 validatorListRoot,
        bytes32[][] calldata validatorFields,
        bytes32[] calldata proof,
        uint40[] memory validatorIndices
    ) internal pure {
        uint256 validatorFieldsSize = validatorFields.length;
        uint256 indicesSize = validatorIndices.length;

        if (validatorIndices.length != validatorFields.length) {
            revert BeaconChainProofs__InvalidIndicesAndFields(indicesSize, validatorFieldsSize);
        }
        
        Merkle.Node[] memory validatorFieldNodes = new Merkle.Node[](validatorFieldsSize);
        for (uint256 i = 0; i < validatorFields.length; i++) {
            if (validatorFields[i].length != (2 ** VALIDATOR_FIELD_TREE_HEIGHT)) {
                revert BeaconChainProofs__InvalidValidatorField(i);
            }
            // merkleize the validatorFields to get the leaf to prove
            bytes32 validatorRoot = Merkle.merkleizeSha256(validatorFields[i]);
            validatorFieldNodes[i] = Merkle.Node(validatorRoot, validatorIndices[i]);
        }
        
        /// NB: We use `VALIDATOR_TREE_HEIGHT + 1` here because the merkle tree of the 
        /// validator list registry includes hashing the root of the validator tree 
        /// with the length of the validator list
        uint256 numLayers = VALIDATOR_TREE_HEIGHT + 1;

        if (
            Merkle.verifyMultiProofInclusionSha256(
                validatorListRoot,
                proof,
                validatorFieldNodes,
                numLayers
            ) == false) {
            revert BeaconChainProofs__InvalidValidatorFieldsMerkleProof();
        }
    }

    /// @notice Verify merkle multiproof of multiple validator balances against BeaconState balance registry
    /// @dev The merkle multiproof proves multiple validator balances in one single proof against the
    /// @param balanceListRoot the merkle root of the BeaconState balance registry list
    /// @param proof merkle multiproof used in proving the multiple validators balances
    /// @param validatorIndices the indices of the validators being provien
    /// @param validatorBalanceRoots the balance roots of the validators being proven
    function verifyMultipleValidatorsBalance(
        bytes32 balanceListRoot,
        bytes32[] calldata proof,
        uint40[] memory validatorIndices,
        bytes32[] memory validatorBalanceRoots
    ) internal pure returns (uint256[] memory validatorBalancesGwei) { 
        uint256 validatorBalancesSize = validatorBalanceRoots.length;
        if (validatorBalancesSize != validatorIndices.length) {
            revert BeaconChainProofs__InvalidIndicesAndBalances();
        }

        Merkle.Node[] memory balanceNodes = new Merkle.Node[](validatorBalancesSize);

        /// NB: We use `BALANCE_TREE_HEIGHT + 1` because the merkle tree of the balance
        /// registry list includes hashing the root of the balances tree with the length 
        /// of the balance registry list
        uint256 numLayers = BALANCE_TREE_HEIGHT + 1;

        validatorBalancesGwei = new uint256[](validatorBalancesSize);
        for (uint256 i = 0; i < validatorBalancesSize; i++) {
            /// beacon chain balances are combined into groups of 4 called balanceRoots
            /// diving by 4 allows to get the balance index of a validator      
            uint256 balanceIndex = validatorIndices[i] / 4;
            balanceNodes[i] = Merkle.Node(validatorBalanceRoots[i], balanceIndex);

            validatorBalancesGwei[i] = uint256(getBalanceAtIndex(validatorBalanceRoots[i], validatorIndices[i]));
        }

        if (
            Merkle.verifyMultiProofInclusionSha256(
                balanceListRoot,
                proof,
                balanceNodes,
                numLayers
            ) == false) {
            revert BeaconChainProofs__InvalidMerkleProof();
        }
    }

    /// @notice Verify merkle proof of BeaconState validator Registry list against Beacon block root
    /// @dev This proof begins at the Validator List registry root, proceeds through the BeaconState root, 
    /// and continues through the Beacon block root. Consequently, it includes elements of a StateRootProof 
    /// under the same block root.
    /// @dev This makes checkpoint proofs shorter, as a checkpoint will verify multiple validator fields
    /// against the same BeaconState validator registry list root.
    /// @param beaconBlockRoot merkle root of the beacon block
    /// @param proof Contains the validator list root and merkle proof
    function verifyValidatorListRootAgainstBlockRoot(
        bytes32 beaconBlockRoot,
        ValidatorRegistryProof calldata proof
    ) internal view {
        if (
            proof.proof.length != 32 * (BEACON_BLOCK_HEADER_FIELD_TREE_HEIGHT + BEACON_STATE_TREE_HEIGHT)
        ) {
            revert BeaconChainProofs__InvalidProofSize();
        }
        /// This proof combines two proofs, the index accounts for the relative position of leaves in two trees:
        /// beaconBlockRoot HEIGHT: BEACON_BLOCK_HEADER_TREE_HEIGHT
        /// /\                           
        /// beaconStateRoot HEIGHT: BEACON_STATE_TREE_HEIGHT
        /// /\                            
        /// validatorListRoot
        uint256 validatorIndex = (STATE_ROOT_INDEX << (BEACON_STATE_TREE_HEIGHT)) | VALIDATOR_LIST_INDEX;

        if (Merkle.verifyInclusionSha256({
                proof: proof.proof,
                root: beaconBlockRoot,
                leaf: proof.validatorListRoot,
                index: validatorIndex
        }) == false) {
            revert BeaconChainProofs__InvalidValidatorRootProof();
        }
    }

    /// @notice Verify a merkle proof of the BeaconState balances registry against the beacon block root
    /// @dev This proof begins at the Balance List registry root, proceeds through the BeaconState root, 
    /// and continues through the Beacon block root. Consequently, it includes elements of a StateRootProof 
    /// under the same block root.
    /// @dev This makes checkpoint proofs shorter, as a checkpoint will verify multiple validator balances
    /// against the same balance registry list root.
    /// @param beaconBlockRoot merkle root of the beacon block
    /// @param proof a beacon balance registry root and merkle proof of its inclusion under `beaconBlockRoot`
    function verifyBalanceRootAgainstBlockRoot(
        bytes32 beaconBlockRoot,
        BalanceRegistryProof calldata proof
    ) internal view {
        if (
            proof.proof.length != 32 * (BEACON_BLOCK_HEADER_FIELD_TREE_HEIGHT + BEACON_STATE_TREE_HEIGHT)
        ) {
            revert BeaconChainProofs__InvalidProofSize();
        }

        /// This proof combines two proofs, so its index accounts for the relative position of leaves in two trees:
        /// beaconBlockRoot HEIGHT: BEACON_BLOCK_HEADER_TREE_HEIGHT
        /// /\                            
        /// beaconStateRoot HEIGHT: BEACON_STATE_TREE_HEIGHT
        /// /\                            
        /// balancesListRoot
        uint256 index = (STATE_ROOT_INDEX << (BEACON_STATE_TREE_HEIGHT)) | BALANCE_LIST_ROOT_INDEX;

        if (Merkle.verifyInclusionSha256({
                proof: proof.proof,
                root: beaconBlockRoot,
                leaf: proof.balanceListRoot,
                index: index
        }) == false) {
            revert BeaconChainProofs__InvalidBalanceRootProof();
        }
    }

    /// @notice Parses a balanceRoot to get the uint64 balance of a validator.  
    /// @param balanceRoot is the combination of 4 validator balances being proven for
    /// @param validatorIndex index of the validator
    /// @return validator balance in Gwei
    function getBalanceAtIndex(bytes32 balanceRoot, uint40 validatorIndex) internal pure returns (uint64) {
        uint256 bitShiftAmount = (validatorIndex % 4) * 64;
        return 
            Endian.fromLittleEndianUint64(bytes32((uint256(balanceRoot) << bitShiftAmount)));
    }

    /// @dev Get a validator pubkey hash
    function getPubkeyHash(bytes32[] calldata validatorFields) internal pure returns (bytes32) {
        return 
            validatorFields[VALIDATOR_PUBKEY_INDEX];
    }

    /// @dev Get a validator withdrawal credential
    function getWithdrawalCredentials(bytes32[] calldata validatorFields) internal pure returns (bytes32) {
        return
            validatorFields[VALIDATOR_WITHDRAWAL_CREDENTIALS_INDEX];
    }

    /// @dev Get a validator effective balance in Gwei
    function getEffectiveBalanceGwei(bytes32[] calldata validatorFields) internal pure returns (uint64) {
        return 
            Endian.fromLittleEndianUint64(validatorFields[VALIDATOR_BALANCE_INDEX]);
    }

    /// @dev Get a validator withdrawable epoch
    function getWithdrawableEpoch(bytes32[] calldata validatorFields) internal pure returns (uint64) {
        return 
            Endian.fromLittleEndianUint64(validatorFields[VALIDATOR_WITHDRAWABLE_EPOCH_INDEX]);
    }

    /// @dev Get a validator exit epoch
    function getExitEpoch(bytes32[] calldata validatorFields) internal pure returns (uint64) {
        return 
            Endian.fromLittleEndianUint64(validatorFields[VALIDATOR_EXIT_EPOCH_INDEX]);
    }

    /// @dev Get a validator activation epoch
    function getActivationEpoch(bytes32[] calldata validatorFields) internal pure returns (uint64) {
        return Endian.fromLittleEndianUint64(validatorFields[VALIDATOR_ACTIVATION_EPOCH_INDEX]);
    }

    /// @dev Returns if a validator is slashed
    function isValidatorSlashed(bytes32[] calldata validatorFields) internal pure returns (bool) {
        return validatorFields[VALIDATOR_SLASHED_INDEX] != bytes32(0);
    }

}
