// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IProofVerifier {

    enum VALIDATOR_STATUS {
        INACTIVE, // doesnt exist
        ACTIVE, // staked on ethpos and withdrawal credentials are pointed to the EigenPod
        WITHDRAWN // withdrawn from the Beacon Chain
    }

    struct Withdrawal {
        bytes32 validatorPubKeyHash;
        uint256 amountToSendGwei;
        uint64 withdrawalTimestamp;
        VALIDATOR_STATUS status;
        // `@TODO add validator status
    }

    error Invalid_Timestamp(uint256 timestamp);

    function verifyWithdrawal(
        uint256 oracleTimestamp,
        bytes calldata proof
    ) external view returns(Withdrawal memory);
}