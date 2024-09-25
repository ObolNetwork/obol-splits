// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ISymPodFactory {

    error SymPodFactory__InvalidAdmin();
    error SymPodFactory__InvalidWithdrawalRecipient();
    error SymPodFactory__InvalidRecoveryRecipient();

    event CreateSymPod(
        address symPod,
        address admin,
        address withdrawalAddress,
        address recoveryRecipient
    );
}