// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";

struct SplitConfiguration {
  address[] accounts;
  uint32[] percentAllocations;
  uint32 distributorFee;
  address controller;
}

interface ISplitMain {
  /// @notice Creates a new split with recipients `accounts` with ownerships
  /// `percentAllocations`, a
  /// keeper fee for splitting of `distributorFee` and the controlling address
  /// `controller`
  /// @param accounts Ordered, unique list of addresses with ownership in the
  /// split
  /// @param percentAllocations Percent allocations associated with each
  /// address
  /// @param distributorFee Keeper fee paid by split to cover gas costs of
  /// distribution
  /// @param controller Controlling address (0x0 if immutable)
  /// @return split Address of newly created split
  function createSplit(
    address[] calldata accounts,
    uint32[] calldata percentAllocations,
    uint32 distributorFee,
    address controller
  ) external returns (address);

  /// @notice Predicts the address for an immutable split created with
  /// recipients `accounts` with
  /// ownerships `percentAllocations` and a keeper fee for splitting of
  /// `distributorFee`
  /// @param accounts Ordered, unique list of addresses with ownership in the
  /// split
  /// @param percentAllocations Percent allocations associated with each
  /// address
  /// @param distributorFee Keeper fee paid by split to cover gas costs of
  /// distribution
  /// @return split Predicted address of such an immutable split
  function predictImmutableSplitAddress(
    address[] calldata accounts,
    uint32[] calldata percentAllocations,
    uint32 distributorFee
  ) external view returns (address split);

  /// @notice Distributes the ETH balance for split `split`
  /// @dev `accounts`, `percentAllocations`, and `distributorFee` are verified
  /// by hashing
  /// & comparing to the hash in storage associated with split `split`
  /// @param split Address of split to distribute balance for
  /// @param accounts Ordered, unique list of addresses with ownership in the
  /// split
  /// @param percentAllocations Percent allocations associated with each
  /// address
  /// @param distributorFee Keeper fee paid by split to cover gas costs of
  /// distribution
  /// @param distributorAddress Address to pay `distributorFee` to
  function distributeETH(
    address split,
    address[] calldata accounts,
    uint32[] calldata percentAllocations,
    uint32 distributorFee,
    address distributorAddress
  ) external;

  /// @notice Distributes the ERC20 `token` balance for split `split`
  /// @dev `accounts`, `percentAllocations`, and `distributorFee` are verified
  /// by hashing
  /// & comparing to the hash in storage associated with split `split`
  /// @dev pernicious ERC20s may cause overflow in this function inside
  /// _scaleAmountByPercentage, but results do not affect ETH & other ERC20
  /// balances
  /// @param split Address of split to distribute balance for
  /// @param token Address of ERC20 to distribute balance for
  /// @param accounts Ordered, unique list of addresses with ownership in the
  /// split
  /// @param percentAllocations Percent allocations associated with each
  /// address
  /// @param distributorFee Keeper fee paid by split to cover gas costs of
  /// distribution
  /// @param distributorAddress Address to pay `distributorFee` to
  function distributeERC20(
    address split,
    ERC20 token,
    address[] calldata accounts,
    uint32[] calldata percentAllocations,
    uint32 distributorFee,
    address distributorAddress
  ) external;

  /// @notice Withdraw ETH &/ ERC20 balances for account `account`
  /// @param account Address to withdraw on behalf of
  /// @param withdrawETH Withdraw all ETH if nonzero
  /// @param tokens Addresses of ERC20s to withdraw
  function withdraw(address account, uint256 withdrawETH, ERC20[] calldata tokens) external;

  /// @notice Updates an existing split with recipients `accounts` with
  /// ownerships `percentAllocations` and a keeper fee
  /// for splitting of `distributorFee`
  /// @param split Address of mutable split to update
  /// @param accounts Ordered, unique list of addresses with ownership in the
  /// split
  /// @param percentAllocations Percent allocations associated with each
  /// address
  /// @param distributorFee Keeper fee paid by split to cover gas costs of
  /// distribution
  function updateSplit(
    address split,
    address[] calldata accounts,
    uint32[] calldata percentAllocations,
    uint32 distributorFee
  ) external;

  function getHash(address split) external view returns (bytes32);
}
