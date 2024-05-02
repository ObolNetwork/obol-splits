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
        address rewardRecipient
    );

    /// @notice Emitted on settting new state proof verifier
    /// @param oldVerifier previous verifier address
    /// @param newVerifier new veriifer adddress
    /// @param timestamp block timestamp
    event UpdateStateProofVerifier(
        address indexed oldVerifier,
        address newVerifier,
        uint256 timestamp
    );

    /// @notice Invalid address
    error Invalid__Address();

    /// @notice Returns verifier address
    function getVerifier() external returns (address);

}