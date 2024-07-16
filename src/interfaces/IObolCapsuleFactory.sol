// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IObolCapsuleFactory {

    /// @notice Emitted on deploying new capsule
    /// @param capsule Address of newly deployed capsule
    /// @param principalRecipient Address to receive principal
    /// @param rewardRecipient Address to receive rewards
    event CreateCapsule(
        address indexed capsule,
        address principalRecipient,
        address rewardRecipient,
        address recoveryRecipient
    );

    /// @notice Invalid address
    error Invalid__Address();
    error Invalid__RewardRecipient();
    error Invalid__PrincipalRecipient();
    error Invalid__RecoveryRecipient();


}