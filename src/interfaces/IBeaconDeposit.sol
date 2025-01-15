// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

/**
 * @title IBeaconDeposit
 * @notice Interface for the Ethereum 2.0 deposit contract
 * @dev Based on the official deposit contract at 0x00000000219ab540356cBB839Cbe05303d7705Fa
 */
interface IBeaconDeposit {
    /// @notice Submit a Phase 0 DepositData object
    /// @param pubkey A BLS12-381 public key
    /// @param withdrawalCredentials Commitment to a public key for withdrawals
    /// @param signature A BLS12-381 signature
    /// @param depositDataRoot The SHA-256 hash of the SSZ-encoded DepositData object
    function deposit(
        bytes calldata pubkey,
        bytes calldata withdrawalCredentials,
        bytes calldata signature,
        bytes32 depositDataRoot
    ) external payable;

    /// @notice Query the current deposit root hash
    /// @return The deposit root hash
    function get_deposit_root() external view returns (bytes32);

    /// @notice Query the current deposit count
    /// @return The deposit count
    function get_deposit_count() external view returns (bytes memory);
}
