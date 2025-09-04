// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

/// @title IObolValidatorManager
/// @author Obol
/// @dev The interface for ObolValidatorManager contract.
interface IObolValidatorManager {
  /// -----------------------------------------------------------------------
  /// ObolValidatorManager functions
  /// -----------------------------------------------------------------------

  /// @notice Submit a Phase 0 DepositData object.
  /// @param pubkey A BLS12-381 public key.
  /// @param withdrawal_credentials Commitment to a public key for withdrawals.
  /// @param signature A BLS12-381 signature.
  /// @param deposit_data_root The SHA-256 hash of the SSZ-encoded DepositData object.
  /// Used as a protection against malformed input.
  function deposit(
    bytes calldata pubkey,
    bytes calldata withdrawal_credentials,
    bytes calldata signature,
    bytes32 deposit_data_root
  ) external payable;

  /// @notice Set the principal recipient address
  /// @param newPrincipalRecipient New address to receive principal funds
  function setPrincipalRecipient(address newPrincipalRecipient) external;

  /// @notice Overrides the current amount of principal stake
  /// @param newAmount New amount of principal stake (wei)
  /// @dev The amount of principal stake is usually increased via deposit() call,
  ///      but in certain cases, it may need to be changed explicitly.
  function setAmountOfPrincipalStake(uint256 newAmount) external;

  /// Distributes target token inside the contract to recipients
  /// @dev pushes funds to recipients
  function distributeFunds() external;

  /// Distributes target token inside the contract to recipients
  /// @dev Backup recovery if any recipient tries to brick the OVM for
  /// remaining recipients
  function distributeFundsPull() external;

  /// Request validators consolidation with the EIP7251 system contract
  /// @dev All source validators will be consolidated into the target validator.
  ///      The caller must compute the fee before calling and send a sufficient msg.value amount.
  ///      Excess amount will be refunded.
  /// @param sourcePubKeys Validator public keys to be consolidated
  /// @param targetPubKey Target validator public key
  function requestConsolidation(bytes[] calldata sourcePubKeys, bytes calldata targetPubKey) external payable;

  /// Request partial/full withdrawal from the EIP7002 system contract
  /// @dev The caller must compute the fee before calling and send a sufficient msg.value amount.
  ///      Excess amount will be refunded.
  ///      Withdrawals that leave a validator with (0..32) ether
  ///      will only withdraw an amount that leaves the validator at 32 ether.
  /// @param pubKeys Validator public keys
  /// @param amounts Withdrawal amounts in gwei.
  ///                Any amount below principalThreshold will be distributed as reward.
  ///                Any amount >= principalThreshold will be distributed as principal.
  function requestWithdrawal(bytes[] calldata pubKeys, uint64[] calldata amounts) external payable;

  /// Recover non-OVM tokens to a recipient
  /// @param nonOVMToken Token to recover (cannot be OVM token)
  /// @param recipient Address to receive recovered token
  function recoverFunds(address nonOVMToken, address recipient) external;

  /// Withdraw token balance for an account
  /// @param account Address to withdraw on behalf of
  function withdraw(address account) external;

  /// Returns the balance for the account `account`
  /// @param account Account to return balance for
  /// @return Account's withdrawable ether balance
  function getPullBalance(address account) external view returns (uint256);

  /// -----------------------------------------------------------------------
  /// ObolValidatorManager variable getters
  /// -----------------------------------------------------------------------

  /// @notice Returns the consolidation system contract address
  /// @return Address of the EIP7251 consolidation system contract
  function consolidationSystemContract() external view returns (address);

  /// @notice Returns the withdrawal system contract address
  /// @return Address of the EIP7002 withdrawal system contract
  function withdrawalSystemContract() external view returns (address);

  /// @notice Returns the deposit system contract address
  /// @return Address of the Ethereum deposit contract
  function depositSystemContract() external view returns (address);

  /// @notice Returns the current principal recipient address
  /// @return Address that receives principal stake distributions
  function principalRecipient() external view returns (address);

  /// @notice Returns the reward recipient address
  /// @return Address that receives reward distributions
  function rewardRecipient() external view returns (address);

  /// @notice Returns the principal classification threshold
  /// @return Threshold in gwei for classifying withdrawals as principal vs reward
  function principalThreshold() external view returns (uint64);

  /// @notice Returns the total amount of principal stake deposited
  /// @return Total principal stake in wei deposited via deposit() function
  function amountOfPrincipalStake() external view returns (uint256);

  /// @notice Returns the amount of funds pending withdrawal in pull flow
  /// @return Amount in wei set aside for pull withdrawals
  function fundsPendingWithdrawal() external view returns (uint128);

  /// -----------------------------------------------------------------------
  /// OwnableRoles functions
  /// -----------------------------------------------------------------------

  /// @dev Allows the owner to grant `user` `roles`.
  /// If the `user` already has a role, then it will be a no-op for the role.
  function grantRoles(address user, uint256 roles) external payable;

  /// @dev Allows the owner to remove `user` `roles`.
  /// If the `user` does not have a role, then it will be a no-op for the role.
  function revokeRoles(address user, uint256 roles) external payable;

  /// @dev Allow the caller to remove their own roles.
  /// If the caller does not have a role, then it will be a no-op for the role.
  function renounceRoles(uint256 roles) external payable;

  /// @dev Returns the roles of `user`.
  function rolesOf(address user) external view returns (uint256 roles);

  /// @dev Returns whether `user` has any of `roles`.
  function hasAnyRole(address user, uint256 roles) external view returns (bool);

  /// @dev Returns whether `user` has all of `roles`.
  function hasAllRoles(address user, uint256 roles) external view returns (bool);

  /// -----------------------------------------------------------------------
  /// Ownable functions
  /// -----------------------------------------------------------------------

  /// @dev Allows the owner to transfer the ownership to `newOwner`.
  function transferOwnership(address newOwner) external payable;

  /// @dev Allows the owner to renounce their ownership.
  function renounceOwnership() external payable;

  /// @dev Request a two-step ownership handover to the caller.
  /// The request will automatically expire in 48 hours (172800 seconds) by default.
  function requestOwnershipHandover() external payable;

  /// @dev Cancels the two-step ownership handover to the caller, if any.
  function cancelOwnershipHandover() external payable;

  /// @dev Allows the owner to complete the two-step ownership handover to `pendingOwner`.
  /// Reverts if there is no existing ownership handover requested by `pendingOwner`.
  function completeOwnershipHandover(address pendingOwner) external payable;

  /// @dev Returns the owner of the contract.
  function owner() external view returns (address result);

  /// @dev Returns the expiry timestamp for the two-step ownership handover to `pendingOwner`.
  function ownershipHandoverExpiresAt(address pendingOwner) external view returns (uint256 result);
}
