// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";

interface IProofVerifier {
    
    error Invalid_Timestamp(uint256 timestamp);

    function verifyExitProof(
        uint256 oracleTimestamp,
        bytes32 withdrawalCredentials,
        BeaconChainProofs.ValidatorListAndBalanceListRootProof calldata vbProof,
        BeaconChainProofs.BalanceProof calldata balanceProof,
        BeaconChainProofs.ValidatorProof calldata validatorProof
    ) external view returns(uint256 totalExitedBalanceEther);

}