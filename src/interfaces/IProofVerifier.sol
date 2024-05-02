// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IProofVerifier {
    function isValidWithdrawalProof(
        bytes calldata proof
    ) external returns (bool); 

    function isValidExitProof(bytes calldata proof) external returns (bool);

}