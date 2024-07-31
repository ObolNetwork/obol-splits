// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./Merkle.sol";
import "../libraries/Endian.sol";

//Utility library for parsing and PHASE0 beacon chain block headers
//SSZ Spec: https://github.com/ethereum/consensus-specs/blob/dev/ssz/simple-serialize.md#merkleization
//BeaconBlockHeader Spec: https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#beaconblockheader
//BeaconState Spec: https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#beaconstate
library BeaconChainProofs {
    error BeaconChainProofs__InvalidValidatorRootandBalanceRootProof();
    error BeaconChainProofs__InvalidProofSize();

    error BeaconChainProofs__InvalidValidatorField(uint256 index);
    error BeaconChainProofs__InvalidIndicesAndFields(uint256 indexSize, uint256 fieldSize);
    error BeaconChainProofs__InvalidValidatorFieldsMerkleProof();
    error BeaconChainProofs__InvalidIndicesAndBalances();
    error BeaconChainProofs__IncorrectWithdrawalCredentials(bytes32 pubkeyHash);

    // constants are the number of fields and the heights of the different merkle trees used in merkleizing beacon chain containers
    uint256 internal constant BEACON_BLOCK_HEADER_FIELD_TREE_HEIGHT = 3;
    uint256 internal constant BEACON_STATE_TREE_HEIGHT = 5;

    uint256 internal constant NUM_BEACON_BLOCK_BODY_FIELDS = 11;
    uint256 internal constant BEACON_BLOCK_BODY_FIELD_TREE_HEIGHT = 4;

    uint256 internal constant NUM_BEACON_STATE_FIELDS = 21;
    uint256 internal constant BEACON_STATE_FIELD_TREE_HEIGHT = 5;
    uint256 internal constant BALANCE_TREE_HEIGHT = 38;

    uint256 internal constant NUM_VALIDATOR_FIELDS = 8;
    uint256 internal constant VALIDATOR_FIELD_TREE_HEIGHT = 3;

    //Index of block_summary_root in historical_summary container
    uint256 internal constant BLOCK_SUMMARY_ROOT_INDEX = 0;

    uint256 internal constant NUM_WITHDRAWAL_FIELDS = 4;
    // tree height for hash tree of an individual withdrawal container
    uint256 internal constant WITHDRAWAL_FIELD_TREE_HEIGHT = 2;

    uint256 internal constant VALIDATOR_TREE_HEIGHT = 40;

    // MAX_WITHDRAWALS_PER_PAYLOAD = 2**4, making tree height = 4
    uint256 internal constant WITHDRAWALS_TREE_HEIGHT = 4;

    //in beacon block body https://github.com/ethereum/consensus-specs/blob/dev/specs/capella/beacon-chain.md#beaconblockbody
    uint256 internal constant EXECUTION_PAYLOAD_INDEX = 9;

    // in beacon block header https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#beaconblockheader
    uint256 internal constant SLOT_INDEX = 0;
    uint256 internal constant PROPOSER_INDEX_INDEX = 1;
    uint256 internal constant STATE_ROOT_INDEX = 3;
    uint256 internal constant BODY_ROOT_INDEX = 4;

    //  in beacon state https://github.com/ethereum/consensus-specs/blob/dev/specs/capella/beacon-chain.md#beaconstate
    uint256 internal constant VALIDATOR_LIST_INDEX = 11;
    uint256 internal constant BALANCE_LIST_INDEX = 12;

    // in validator https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#validator
    uint256 internal constant VALIDATOR_PUBKEY_INDEX = 0;
    uint256 internal constant VALIDATOR_WITHDRAWAL_CREDENTIALS_INDEX = 1;
    uint256 internal constant VALIDATOR_BALANCE_INDEX = 2;
    uint256 internal constant VALIDATOR_SLASHED_INDEX = 3;
    uint256 internal constant VALIDATOR_EXIT_EPOCH_INDEX = 6;
    uint256 internal constant VALIDATOR_WITHDRAWABLE_EPOCH_INDEX = 7;

    //Misc Constants
    /// @notice Far future epoch. used as exit epoch for non-exited validators
    /// @dev https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md?plain=1#L185
    uint256 internal constant FAR_FUTURE_EPOCH = (2**64) - 1;

    /// @notice https://github.com/ethereum/consensus-specs/blob/9be05296fa937dc138b781d5e7429a50fe4997b5/presets/mainnet/phase0.yaml#L54
    uint256 internal constant EPOCHS_PER_SLASHINGS_VECTOR = 8192;

    /// @dev defined epoch boundary
    /// https://github.com/ethereum/consensus-specs/blob/9be05296fa937dc138b781d5e7429a50fe4997b5/presets/mainnet/phase0.yaml#L36
    uint256 internal constant EPOCH = 6.4 minutes;


    /// @notice This struct contains the root and proof for verifying the state root against the oracle block root
    struct ValidatorListAndBalanceListRootProof {
        bytes32[] proof;
    }

    struct ValidatorProof {
        bytes32 validatorListRoot;
        bytes32[][] validatorFields;
        bytes32[] proof;
        uint40[] validatorIndices;
    }

    struct BalanceProof {
        bytes32 balanceListRoot;
        bytes32[] proof;
        bytes32[] validatorBalances;
    }
    
    /// @notice This function verifies merkle proofs of the fields of a certain validator against a beacon chain state root
    /// @param validatorListRoot is the validator list root to be proven against.
    /// @param validatorFields the claimed fields of the validators being provien
    /// @param validatorIndices the indices of the proven validator
    /// @param proof is the data used in proving the validator's fields
    function verifyValidatorFields(
        bytes32 validatorListRoot,
        bytes32[][] memory validatorFields,
        bytes32[] memory proof,
        uint40[] memory validatorIndices
    ) internal view {

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
        
        /**
         * Note: the length of the validator merkle proof is BeaconChainProofs.VALIDATOR_TREE_HEIGHT + 1.
         * There is an additional layer added by hashing the root with the length of the validator list
         */
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


    function verifyValidatorsBalance(
        bytes32 balanceListRoot,
        bytes32[] memory proof,
        uint40[] memory validatorIndices,
        bytes32[] memory validatorBalances
    ) internal view {
        
        uint256 validatorBalancesSize = validatorBalances.length;
        if (validatorBalancesSize != validatorIndices.length) {
            revert BeaconChainProofs__InvalidIndicesAndBalances();
        }

        Merkle.Node[] memory balanceNodes = new Merkle.Node[](validatorBalancesSize);

        uint256 numLayers = BALANCE_TREE_HEIGHT + 1;

        /**
         * 
         */
        for (uint256 i = 0; i < validatorBalancesSize; i++) {
            uint256 index = validatorIndices[i] / 4;
            balanceNodes[i] = Merkle.Node(validatorBalances[i], index);
        }

        if (
            Merkle.verifyMultiProofInclusionSha256(
                balanceListRoot,
                proof,
                balanceNodes,
                numLayers
            ) == false) {
            revert BeaconChainProofs__InvalidValidatorFieldsMerkleProof();
        }

        // require(
        //     proof.proof.length == 32 * (BEACON_BLOCK_HEADER_TREE_HEIGHT + BEACON_STATE_TREE_HEIGHT),
        //     "BeaconChainProofs.verifyBalanceContainer: Proof has incorrect length"
        // );

        // /// This proof combines two proofs, so its index accounts for the relative position of leaves in two trees:
        // /// - beaconBlockRoot
        // /// |                            HEIGHT: BEACON_BLOCK_HEADER_TREE_HEIGHT
        // /// -- beaconStateRoot
        // /// |                            HEIGHT: BEACON_STATE_TREE_HEIGHT
        // /// ---- balancesContainerRoot
        // uint256 index = (STATE_ROOT_INDEX << (BEACON_STATE_TREE_HEIGHT)) | BALANCE_CONTAINER_INDEX;
        
        // require(
        //     Merkle.verifyInclusionSha256({
        //         proof: proof.proof,
        //         root: beaconBlockRoot,
        //         leaf: proof.balanceContainerRoot,
        //         index: index
        //     }),
        //     "BeaconChainProofs.verifyBalanceContainer: invalid balance container proof"
        // );
    }

    
    /// @notice This function verifies validatorListRoot and BalanceListRoot against the block root. 
    /// @param blockRoot merkle root of the beacon block
    /// @param validatorListRoot is the beacon chain state root to be proven against.
    /// @param balanceListRoot is the provided merkle proof
    /// @param multiProof is hashtree root of the latest block header in the beacon state
    function verifyValidatorRootAndBalanceRootAgainstBlockRoot(
        bytes32 blockRoot,
        bytes32 validatorListRoot,
        bytes32 balanceListRoot,
        bytes32[] memory multiProof
    ) internal view {      
        // verify proof size
        uint256 proofSize = 9;
        if (multiProof.length != proofSize) {
            revert BeaconChainProofs__InvalidProofSize();
        }
        /// This proof combines two proofs, so its index accounts for the relative position of leaves in two trees:
        /// - beaconBlockRoot
        /// |                            HEIGHT: BEACON_BLOCK_HEADER_TREE_HEIGHT
        /// -- beaconStateRoot 
        /// |                            HEIGHT: BEACON_STATE_TREE_HEIGHT
        /// ---- balancesContainerRoot, validatorListRoot
        uint256 balanceIndex = (STATE_ROOT_INDEX << (BEACON_STATE_TREE_HEIGHT)) | BALANCE_LIST_INDEX;
        uint256 validatorIndex = (STATE_ROOT_INDEX << (BEACON_STATE_TREE_HEIGHT)) | VALIDATOR_LIST_INDEX;

        uint256 numLayers = BEACON_BLOCK_HEADER_FIELD_TREE_HEIGHT + BEACON_STATE_TREE_HEIGHT;

        Merkle.Node[] memory leaves = new Merkle.Node[](2);
        leaves[0] = Merkle.Node(validatorListRoot, validatorIndex);
        leaves[1] = Merkle.Node(balanceListRoot, balanceIndex);

        if (
            Merkle.verifyMultiProofInclusionSha256(
                blockRoot,
                multiProof,
                leaves,
                numLayers
            ) == false) {
            revert BeaconChainProofs__InvalidValidatorRootandBalanceRootProof();
        }
    }

    /// @notice This function verifies a validator withdrawal credentials
    function verifyValidatorWithdrawalCredentials(bytes32[] memory validatorFields, bytes32 withdrawalCredentials) internal pure {
        if (getWithdrawalCredentials(validatorFields) != withdrawalCredentials) {
            revert BeaconChainProofs__IncorrectWithdrawalCredentials(getPubkeyHash(validatorFields));
        }
    }

    /**
     * @notice Parses a balanceRoot to get the uint64 balance of a validator.  
     * @dev During merkleization of the beacon state balance tree, four uint64 values are treated as a single 
     * leaf in the merkle tree. We use validatorIndex % 4 to determine which of the four uint64 values to 
     * extract from the balanceRoot.
     * @param balanceRoot is the combination of 4 validator balances being proven for
     * @param validatorIndex is the index of the validator being proven for
     * @return The validator's balance, in Gwei
     */
    function getBalanceAtIndex(bytes32 balanceRoot, uint40 validatorIndex) internal pure returns (uint64) {
        uint256 bitShiftAmount = (validatorIndex % 4) * 64;
        return 
            Endian.fromLittleEndianUint64(bytes32((uint256(balanceRoot) << bitShiftAmount)));
    }

    /**
     * @notice This function replicates the ssz hashing of a validator's pubkey, outlined below:
     *  hh := ssz.NewHasher()
     *  hh.PutBytes(validatorPubkey[:])
     *  validatorPubkeyHash := hh.Hash()
     *  hh.Reset()
     */
    function hashValidatorBLSPubkey(bytes memory validatorPubkey) internal pure returns (bytes32 pubkeyHash) {
        require(validatorPubkey.length == 48, "Input should be 48 bytes in length");
        return sha256(abi.encodePacked(validatorPubkey, bytes16(0)));
    }

    /**
     * Indices for validator fields (refer to consensus specs):
     * 0: pubkey
     * 1: withdrawal credentials
     * 2: effective balance
     * 3: slashed?
     * 4: activation elligibility epoch
     * 5: activation epoch
     * 6: exit epoch
     * 7: withdrawable epoch
     */

    /**
     * @dev Retrieves a validator's pubkey hash
     */
    function getPubkeyHash(bytes32[] memory validatorFields) internal pure returns (bytes32) {
        return 
            validatorFields[VALIDATOR_PUBKEY_INDEX];
    }

    function getWithdrawalCredentials(bytes32[] memory validatorFields) internal pure returns (bytes32) {
        return
            validatorFields[VALIDATOR_WITHDRAWAL_CREDENTIALS_INDEX];
    }

    /**
     * @dev Retrieves a validator's effective balance (in gwei)
     */
    function getEffectiveBalanceGwei(bytes32[] memory validatorFields) internal pure returns (uint64) {
        return 
            Endian.fromLittleEndianUint64(validatorFields[VALIDATOR_BALANCE_INDEX]);
    }

    /**
     * @dev Retrieves a validator's withdrawable epoch
     */
    function getWithdrawableEpoch(bytes32[] memory validatorFields) internal pure returns (uint64) {
        return 
            Endian.fromLittleEndianUint64(validatorFields[VALIDATOR_WITHDRAWABLE_EPOCH_INDEX]);
    }

    function getExitEpoch(bytes32[] memory validatorFields) internal pure returns (uint64) {
        return 
            Endian.fromLittleEndianUint64(validatorFields[VALIDATOR_EXIT_EPOCH_INDEX]);
    }

    function getEpochFromTimestamp(uint256 timestamp, uint256 genesisTime) internal pure returns(uint256 currentEpoch) {
        currentEpoch = (timestamp - genesisTime) / EPOCH;
    }

    function isValidatorSlashed(bytes32[] memory validatorFields) internal pure returns (bool) {
        // TODO verify this value
        return validatorFields[VALIDATOR_SLASHED_INDEX] != bytes32(0);
    }

    /// @dev Returns if a validator has been exited
    function hasValidatorExited(bytes32[] memory validatorFields) internal pure returns (bool) {
        uint256 exitEpoch = getExitEpoch(validatorFields);
        return exitEpoch != FAR_FUTURE_EPOCH;
    }

    /// @dev Returns if a slashed validator has reecieved second penalty
    function hasSlashedValidatorRecievedSecondPenalty(bytes32[] memory validatorFields, uint256 oracleTimestamp, uint256 genesisTime) internal pure returns (bool) {
        uint256 currentEpoch = getEpochFromTimestamp(oracleTimestamp, genesisTime);
        uint64 withdrawalEpoch = getWithdrawableEpoch(validatorFields);
        // the reason for division by 2 https://eth2book.info/capella/annotated-spec/#slashings
        uint256 expectedSecondPenaltyEpoch = withdrawalEpoch - (EPOCHS_PER_SLASHINGS_VECTOR / 2);

        return expectedSecondPenaltyEpoch > currentEpoch;
    }

    function hasExitEpochPassed(bytes32[] memory validatorFields, uint256 oracleTimestamp, uint256 genesisTime) internal pure returns(bool passed) {
        uint256 currentEpoch = getEpochFromTimestamp(oracleTimestamp, genesisTime);
        uint256 exitEpoch = getExitEpoch(validatorFields);
        passed = currentEpoch > exitEpoch;
    }

}
