// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";
import {IProofVerifier} from "src/interfaces/IProofVerifier.sol";



/// @title StateProofVerifierV1
/// @author Obol
/// @notice A beacon state proof verifier staking contract
contract StateProofVerifierV1 is IProofVerifier {
    using BeaconChainProofs for *;

    error Invalid_Inputs();
    error StateProofVerifierV1__ValidatorSlashedMissingSecondPenalty(bytes32 pubkeyHash);
    error StateProofVerifierV1__ValidatorNotExited(bytes32 pubkeyHash);
    error StateProofVerifierV1__IncorrectWithdrawalCredentials(bytes32 pubkeyHash);

    /// @dev beacon roots contract
    address public constant BEACON_BLOCK_ROOTS_CONTRACT = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;
    
    /// @dev version
    uint256 public constant VERSION = 1;

    /// @dev hardfork it supports
    string public HARDFORK;

    constructor() {
        HARDFORK = 'cancun/deneb';
    }

    /// @dev verify Becaon chain validator withdrawals
    /// @param oracleTimestamp beacon block roots timestamp
    /// @param proof withdrawal proofs 
    function verifyExitProof(
        uint256 oracleTimestamp,
        bytes32 withdrawalCredentials,
        bytes calldata proof
    ) external view override returns (
        uint256 totalExitedBalance,
        uint256 leastRecentExitEpoch
    ) {
        (
            BeaconChainProofs.ValidatorListAndBalanceListRootProof memory vbProof,
            BeaconChainProofs.BalanceProof memory balanceProof,
            BeaconChainProofs.ValidatorProof memory validatorProof
        ) = abi.decode(
            proof,
            (
                BeaconChainProofs.ValidatorListAndBalanceListRootProof,
                BeaconChainProofs.BalanceProof,
                BeaconChainProofs.ValidatorProof
            )
        );
            
        // Verify passed-in balanceList and validatorList roots against provided block root:
        BeaconChainProofs.verifyValidatorRootAndBalanceRootAgainstBlockRoot({
            blockRoot: getBeaconBlockRootFromTimestamp(oracleTimestamp),
            validatorListRoot: validatorProof.validatorListRoot,
            balanceListRoot: balanceProof.balanceListRoot,
            multiProof: vbProof.proof
        });

        return _verifyExitProofs(
            oracleTimestamp,
            withdrawalCredentials,
            validatorProof,
            balanceProof
        );
    }

    function _verifyExitProofs(
        uint256 oracleTimestamp,
        bytes32 withdrawalCredentials,
        BeaconChainProofs.ValidatorProof memory validatorProof,
        BeaconChainProofs.BalanceProof memory balanceProof
    ) internal view returns (
        uint256 totalExitedBalance,
        uint256 leastRecentExitEpoch
    ) {       
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
        leastRecentExitEpoch == 0;
        for (uint256 i = 0; i < validatorSize; i++) {

            bytes32[] memory validatorFields = validatorProof.validatorFields[i];

            bytes32 validatorPubkeyHash = validatorFields.getPubkeyHash();
            uint256 exitEpoch = uint256(validatorFields.getExitEpoch());

            if (validatorFields.getWithdrawalCredentials() != withdrawalCredentials) {
                revert StateProofVerifierV1__IncorrectWithdrawalCredentials(validatorPubkeyHash);
            }

            // @TODO verify that non of the validators exit epoch is < than lastsummitedExitEpoch else revert

            if (validatorFields.hasValidatorExited() == false) revert StateProofVerifierV1__ValidatorNotExited(validatorPubkeyHash);

            if (validatorFields.isValidatorSlashed() == true) {
                if (validatorFields.hasSlashedValidatorRecievedSecondPenalty(oracleTimestamp) == false) {
                    revert StateProofVerifierV1__ValidatorSlashedMissingSecondPenalty(validatorPubkeyHash);
                }
            }

            // Write 
            if (leastRecentExitEpoch > exitEpoch || leastRecentExitEpoch == 0) {
                leastRecentExitEpoch = exitEpoch;
            }
            
            totalExitedBalance += BeaconChainProofs.getBalanceAtIndex(
                balanceProof.validatorBalances[i],
                validatorProof.validatorIndices[i]
            );
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