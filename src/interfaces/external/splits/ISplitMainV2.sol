// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";

struct SplitConfiguration {
  address[] accounts;
  uint32[] percentAllocations;
  uint32 distributorFee;
  address distributor;
  address controller;
}

interface ISplitMainV2 {
  /// @notice Creates a new split with recipients `accounts` with ownerships
  /// `percentAllocations`, a
  /// keeper fee for splitting of `distributorFee` and the controlling address
  /// `controller`
  /// @param accounts Ordered, unique list of addresses with ownership in the
  /// split
  /// @param percentAllocations Percent allocations associated with each
  /// address
  /// @param controller Controlling address (0x0 if immutable)
  /// @param distributorFee Keeper fee paid by split to cover gas costs of
  /// distribution
  /// @return split Address of newly created split
  function createSplit(
    address splitWalletImplementation,
    address[] calldata accounts,
    uint32[] calldata percentAllocations,
    address controller,
    address distributor,
    uint32 distributorFee
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
    address splitWalletImplementation,
    address[] calldata accounts,
    uint32[] calldata percentAllocations,
    uint32 distributorFee
  ) external view returns (address split);

  function updateSplit(
    address split,
    address[] calldata accounts,
    uint32[] calldata percentAllocations,
    uint32 distributorFee
  ) external;

  function transferControl(address split, address newController) external;

  function cancelControlTransfer(address split) external;

  function acceptControl(address split) external;

  function makeSplitImmutable(address split) external;

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

  function updateAndDistributeETH(
    address split,
    address[] calldata accounts,
    uint32[] calldata percentAllocations,
    uint32 distributorFee,
    address distributorAddress
  ) external;

  function distributeERC20(
    address split,
    ERC20 token,
    address[] calldata accounts,
    uint32[] calldata percentAllocations,
    uint32 distributorFee,
    address distributorAddress
  ) external;

  function updateAndDistributeERC20(
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

  /**
   * EVENTS
   */

  /**
   * @notice emitted after each successful split creation
   *  @param split Address of the created split
   */
  event CreateSplit(address indexed split);

  /**
   * @notice emitted after each successful split update
   *  @param split Address of the updated split
   */
  event UpdateSplit(address indexed split);

  /**
   * @notice emitted after each initiated split control transfer
   *  @param split Address of the split control transfer was initiated for
   *  @param newPotentialController Address of the split's new potential
   * controller
   */
  event InitiateControlTransfer(address indexed split, address indexed newPotentialController);

  /**
   * @notice emitted after each canceled split control transfer
   *  @param split Address of the split control transfer was canceled for
   */
  event CancelControlTransfer(address indexed split);

  /**
   * @notice emitted after each successful split control transfer
   *  @param split Address of the split control was transferred for
   *  @param previousController Address of the split's previous controller
   *  @param newController Address of the split's new controller
   */
  event ControlTransfer(address indexed split, address indexed previousController, address indexed newController);

  /**
   * @notice emitted after each successful ETH balance split
   *  @param split Address of the split that distributed its balance
   *  @param amount Amount of ETH distributed
   *  @param distributorAddress Address to credit distributor fee to
   */
  event DistributeETH(address indexed split, uint256 amount, address indexed distributorAddress);

  /**
   * @notice emitted after each successful ERC20 balance split
   *  @param split Address of the split that distributed its balance
   *  @param token Address of ERC20 distributed
   *  @param amount Amount of ERC20 distributed
   *  @param distributorAddress Address to credit distributor fee to
   */
  event DistributeERC20(address indexed split, ERC20 indexed token, uint256 amount, address indexed distributorAddress);

  /**
   * @notice emitted after each successful withdrawal
   *  @param account Address that funds were withdrawn to
   *  @param ethAmount Amount of ETH withdrawn
   *  @param tokens Addresses of ERC20s withdrawn
   *  @param tokenAmounts Amounts of corresponding ERC20s withdrawn
   */
  event Withdrawal(address indexed account, uint256 ethAmount, ERC20[] tokens, uint256[] tokenAmounts);
}
