// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";
import {IProofVerifier} from "src/interfaces/IProofVerifier.sol";


/// @title StateProofVerifierV1
/// @author Obol
/// @notice A beacon state proof verifier staking contract
abstract contract StateProofVerifierV1 is IProofVerifier {
    using BeaconChainProofs for *;

    error Invalid_Inputs();
    error StateProofVerifierV1__ValidatorSlashedMissingSecondPenalty(bytes32 pubkeyHash);
    error StateProofVerifierV1__ValidatorNotExited(bytes32 pubkeyHash);
    error StateProofVerifierV1__IncorrectWithdrawalCredentials(bytes32 pubkeyHash);
    error StateProofVerifierV1__ExitEpochNotReached(bytes32 pubkeyHash);
    error StateProofVerifierV1__LateProof(bytes32 pubkeyHash);

    /// @notice Address of the EIP-4788 beacon block root oracle
    /// https://eips.ethereum.org/EIPS/eip-4788
    address public constant BEACON_BLOCK_ROOTS_CONTRACT = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;

    /// @dev Genesis time
    uint256 public immutable GENESIS_TIME;

    constructor(uint256 genesisTime) {
        GENESIS_TIME = genesisTime;
    }

    /// @dev verify Becaon chain validator withdrawals
    /// @param oracleTimestamp beacon block roots timestamp
    /// @param withdrawalCredentials withdrawal credential the validator fields is expected to have
    function verifyExitProof(
        uint256 oracleTimestamp,
        bytes32 withdrawalCredentials,
        BeaconChainProofs.ValidatorListAndBalanceListRootProof calldata vbProof,
        BeaconChainProofs.BalanceProof calldata balanceProof,
        BeaconChainProofs.ValidatorProof calldata validatorProof
    ) public view override returns (uint256 totalExitedBalanceEther) {     
        // Verify passed-in balanceList and validatorList roots against provided block root:
        BeaconChainProofs.verifyValidatorRootAndBalanceRootAgainstBlockRoot({
            blockRoot: getBeaconBlockRootFromTimestamp(oracleTimestamp),
            validatorListRoot: validatorProof.validatorListRoot,
            balanceListRoot: balanceProof.balanceListRoot,
            multiProof: vbProof.proof
        });

        totalExitedBalanceEther = _verifyValidatorAndBalanceProofs(
            oracleTimestamp,
            withdrawalCredentials,
            validatorProof,
            balanceProof
        ) * 1 gwei;
    }

    function _verifyValidatorAndBalanceProofs(
        uint256 oracleTimestamp,
        bytes32 withdrawalCredentials,
        BeaconChainProofs.ValidatorProof calldata validatorProof,
        BeaconChainProofs.BalanceProof calldata balanceProof
    ) internal view returns (uint256 totalExitedBalanceGwei) {       
        // Verify validator fields
        BeaconChainProofs.verifyValidatorFields({
            validatorListRoot: validatorProof.validatorListRoot,
            validatorFields: validatorProof.validatorFields,
            proof: validatorProof.proof,
            validatorIndices: validatorProof.validatorIndices
        });

        // Verify validator balances
        BeaconChainProofs.verifyValidatorsBalance({
            balanceListRoot: balanceProof.balanceListRoot,
            proof: balanceProof.proof,
            validatorIndices: validatorProof.validatorIndices,
            validatorBalances: balanceProof.validatorBalances
        });

        // All proofs are valid
        uint256 validatorSize = validatorProof.validatorIndices.length;
        // leastRecentExitEpoch = 0;
        for (uint256 i = 0; i < validatorSize; i++) {

            bytes32[] memory validatorFields = validatorProof.validatorFields[i];

            bytes32 validatorPubkeyHash = validatorFields.getPubkeyHash();

            // Verify withdrawal credentials
            BeaconChainProofs.verifyValidatorWithdrawalCredentials({
                validatorFields: validatorFields,
                withdrawalCredentials: withdrawalCredentials
            });

            uint256 validatorEffectiveBalanceGwei = BeaconChainProofs.getEffectiveBalanceGwei(
                validatorFields
            );

            if (validatorFields.hasValidatorExited() == false) revert StateProofVerifierV1__ValidatorNotExited(validatorPubkeyHash);
            if (validatorFields.isValidatorSlashed() == true) {
                if (validatorFields.hasSlashedValidatorRecievedSecondPenalty(oracleTimestamp, GENESIS_TIME) == false) {
                    revert StateProofVerifierV1__ValidatorSlashedMissingSecondPenalty(validatorPubkeyHash);
                }
            } else {
                // Check that balance proofs are posted after exit_epoch for a non-slashed validator
                // this is because a validator can be slashed until exit_epoch
                if (validatorFields.hasExitEpochPassed(oracleTimestamp, GENESIS_TIME) == false) {
                    revert StateProofVerifierV1__ExitEpochNotReached(validatorPubkeyHash);
                }
            }

            // @TODO allow non-slashed validators to use effective balance to post proofs?

            uint256 validatorCurrentBalance = BeaconChainProofs.getBalanceAtIndex(
                balanceProof.validatorBalances[i],
                validatorProof.validatorIndices[i]
            );

            // if this balance is zero revert as it should not be zero
            // if (validatorCurrentBalance == 0) {
            //     revert StateProofVerifierV1__LateProof(validatorPubkeyHash);
            // }

            if (validatorCurrentBalance >= validatorEffectiveBalanceGwei) {
                /// if current balance > effective balance - rewards part of current balance
                totalExitedBalanceGwei += validatorEffectiveBalanceGwei;
            } else {
                /// if current balance < effective balance - validator slashed
                totalExitedBalanceGwei += validatorCurrentBalance;
            }
        }
    }

    /// @dev Returns the becaon block root based on timestamp
    /// @param timestamp timestamp to fetch state root 
    /// @return blockRoot beacon block root 
    function getBeaconBlockRootFromTimestamp(uint256 timestamp) public view returns (bytes32 blockRoot) {
        (bool ret, bytes memory data) = BEACON_BLOCK_ROOTS_CONTRACT.staticcall(bytes.concat(bytes32(timestamp)));
        if (ret == false) revert Invalid_Timestamp(timestamp);

        blockRoot = bytes32(data);
    }

}