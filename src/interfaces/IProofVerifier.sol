// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IProofVerifier {

    enum VALIDATOR_STATUS {
        INACTIVE, // doesnt exist
        ACTIVE, // staked on ethpos and withdrawal credentials are pointed to the EigenPod
        WITHDRAWN // withdrawn from the Beacon Chain
    }

    
    
    error Invalid_Timestamp(uint256 timestamp);

    function verifyExitProof(
        uint256 oracleTimestamp,
        bytes32 withdrawalCredentials,
        bytes calldata proof
    ) external view returns(
        uint256 totalExitedBalance,
        uint256 mostRecentExitEpoch
    );
}