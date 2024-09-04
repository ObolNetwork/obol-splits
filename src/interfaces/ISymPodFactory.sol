// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ISymPodFactory {

    event CreateSymPod(
        address symPod,
        address admin,
        address withdrawalAddress,
        address recoveryRecipient
    );
}