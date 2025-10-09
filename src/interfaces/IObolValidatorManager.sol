// SPDX-License-Identifier: Proprietary
pragma solidity 0.8.19;

/// @title IObolValidatorManager
/// @author Obol
/// @dev The interface for ObolValidatorManager contract.
interface IObolValidatorManager {
  /// @notice Struct to represent a consolidation request.
  /// @param srcPubKeys The public keys of the validators to consolidate from.
  /// @param targetPubKey The public key of the validator to consolidate to.
  struct ConsolidationRequest {
    bytes[] srcPubKeys;
    bytes targetPubKey;
  }

  /// -----------------------------------------------------------------------
  /// Events
  /// -----------------------------------------------------------------------

  /// Emitted after beneficiary recipient is changed
  /// @param newBeneficiaryRecipient New beneficiary recipient address
  /// @param oldBeneficiaryRecipient Old beneficiary recipient address
  event NewBeneficiaryRecipient(address indexed newBeneficiaryRecipient, address indexed oldBeneficiaryRecipient);

  /// Emitted after amount of principal stake is changed
  /// @param newPrincipalStakeAmount New amount of principal stake (wei)
  /// @param oldPrincipalStakeAmount Old amount of principal stake (wei)
  event NewAmountOfPrincipalStake(uint256 newPrincipalStakeAmount, uint256 oldPrincipalStakeAmount);

  /// Emitted after reward recipient is changed
  /// @param newRewardRecipient New reward recipient address
  /// @param oldRewardRecipient Old reward recipient address
  event NewRewardRecipient(address indexed newRewardRecipient, address indexed oldRewardRecipient);

  /// Emitted after funds are distributed to recipients
  /// @param principalPayout Amount of principal paid out
  /// @param rewardPayout Amount of reward paid out
  /// @param pullOrPush Flag indicating PULL or PUSH flow
  event DistributeFunds(uint256 principalPayout, uint256 rewardPayout, uint256 pullOrPush);

  /// Emitted after tokens are recovered to a recipient
  /// @param nonOVMToken Recovered token (cannot be ETH)
  /// @param recipient Address receiving recovered token
  /// @param amount Amount of recovered token
  event RecoverNonOVMFunds(address indexed nonOVMToken, address indexed recipient, uint256 amount);

  /// Emitted after funds withdrawn using pull flow
  /// @param account Account withdrawing funds for
  /// @param amount Amount withdrawn
  event PullBalanceWithdrawn(address indexed account, uint256 amount);

  /// Emitted when a Pectra consolidation request is done
  /// @param requester Address of the requester
  /// @param source Source validator public key
  /// @param target Target validator public key
  /// @param fee Fee paid for the consolidation request
  event ConsolidationRequested(address indexed requester, bytes indexed source, bytes indexed target, uint256 fee);

  /// Emitted when a Pectra withdrawal request is done
  /// @param requester Address of the requester
  /// @param pubKey Validator public key
  /// @param amount Withdrawal amount
  /// @param fee Withdrawal fee
  event WithdrawalRequested(address indexed requester, bytes indexed pubKey, uint256 amount, uint256 fee);

  /// Emitted when the excess fee sent as part of a consolidation or withdrawal (partial or full)
  /// request could not be refunded to the excessFeeRecipient.
  /// @param excessFeeRecipient The address to which the excess fee should have been sent.
  /// @param excessFee The amount of excess fee sent.
  event UnsentExcessFee(address indexed excessFeeRecipient, uint256 indexed excessFee);

  /// -----------------------------------------------------------------------
  /// Errors
  /// -----------------------------------------------------------------------

  /// Invalid request params, e.g. empty input
  error InvalidRequest_Params();

  /// Failed to call system contract get_fee()
  error InvalidRequest_SystemGetFee();

  /// Insufficient fee provided in the call's value to conclude the request
  error InvalidRequest_NotEnoughFee();

  /// Failed to call system contract add_consolidation_request()
  error InvalidConsolidation_Failed();

  /// Failed to call system contract add_withdrawal_request()
  error InvalidWithdrawal_Failed();

  /// Invalid distribution
  error InvalidDistribution_TooLarge();

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

  /// @notice Change the beneficiary recipient address
  /// @param newBeneficiaryRecipient New beneficiary recipient address to set
  function setBeneficiaryRecipient(address newBeneficiaryRecipient) external;

  /// @notice Overrides the current amount of principal stake
  /// @param newAmount New amount of principal stake (wei)
  /// @dev The amount of principal stake is usually increased via the deposit() call,
  ///      but in certain cases, it may need to be changed explicitly.
  function setAmountOfPrincipalStake(uint256 newAmount) external;

  /// @notice Set the reward recipient address
  /// @param newRewardRecipient New address to receive reward funds
  function setRewardRecipient(address newRewardRecipient) external;

  /// Distributes target token inside the contract to recipients
  /// @dev Pushes funds to recipients
  function distributeFunds() external;

  /// Distributes target token inside the contract to recipients
  /// @dev Backup recovery if any recipient tries to brick the OVM for
  /// remaining recipients
  function distributeFundsPull() external;

  /// Consolidates validators using the EIP7251 system contract
  /// @dev The excess fee is the difference between the maximum fee and the actual fee paid.
  /// @dev Emits a {UnsentExcessFee} event if the excess fee is not sent.
  /// @param requests An array of consolidation requests.
  /// @param maxFeePerConsolidation The maximum fee allowed per consolidation request.
  /// @param excessFeeRecipient The address to which excess fees will be sent.
  function consolidate(
    ConsolidationRequest[] calldata requests,
    uint256 maxFeePerConsolidation,
    address excessFeeRecipient
  ) external payable;

  /// Withdraws from validators using the EIP7002 system contract
  /// @dev The caller must compute the fee before calling and send a sufficient msg.value amount.
  ///      Excess amount will be refunded.
  ///      Withdrawals that leave a validator with (0..32) ether
  ///      will only withdraw an amount that leaves the validator at 32 ether.
  /// @param pubKeys Validator public keys
  /// @param amounts Withdrawal amounts in gwei.
  ///                Any amount below principalThreshold will be distributed as reward.
  ///                Any amount >= principalThreshold will be distributed as principal.
  ///                Zero amount will trigger a full withdrawal of the validator.
  /// @param maxFeePerWithdrawal The maximum fee allowed per withdrawal.
  /// @param excessFeeRecipient The address to which excess fees will be sent.
  function withdraw(
    bytes[] calldata pubKeys,
    uint64[] calldata amounts,
    uint256 maxFeePerWithdrawal,
    address excessFeeRecipient
  ) external payable;

  /// Recovers non-OVM tokens to a recipient
  /// @param nonOVMToken Token to recover (cannot be OVM token)
  /// @param recipient Address to receive recovered token
  function recoverFunds(address nonOVMToken, address recipient) external;

  /// Withdraws pull balance for an account
  /// @param account Address to withdraw pull balance for
  function withdrawPullBalance(address account) external;

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
  function beneficiaryRecipient() external view returns (address);

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
