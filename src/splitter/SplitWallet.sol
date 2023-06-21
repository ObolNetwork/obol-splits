// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {ISplitMainV2} from "../interfaces/ISplitMainV2.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

/**
 * ERRORS
 */

/// @notice Unauthorized sender
error Unauthorized();

/**
 * @title SplitWallet
 * @author 0xSplits <will@0xSplits.xyz>
 * @notice The implementation logic for `SplitProxy`.
 * @dev `SplitProxy` handles `receive()` itself to avoid the gas cost with `DELEGATECALL`.
 */
contract SplitWallet {
  using SafeTransferLib for address;
  using SafeTransferLib for ERC20;

  /**
   * EVENTS
   */

  /**
   * @notice emitted after each successful ETH transfer to proxy
   *  @param split Address of the split that received ETH
   *  @param amount Amount of ETH received
   */
  event ReceiveETH(address indexed split, uint256 amount);

  /**
   * STORAGE
   */

  /**
   * STORAGE - CONSTANTS & IMMUTABLES
   */

  /// @notice address of SplitMain for split distributions & EOA/SC withdrawals
  ISplitMainV2 public immutable splitMain;

  /**
   * MODIFIERS
   */

  /// @notice Reverts if the sender isn't SplitMain
  modifier onlySplitMain() {
    if (msg.sender != address(splitMain)) revert Unauthorized();
    _;
  }

  /**
   * CONSTRUCTOR
   */

  constructor(address splitMainV2) {
    splitMain = ISplitMainV2(splitMainV2);
  }

  /**
   * FUNCTIONS - PUBLIC & EXTERNAL
   */

  /**
   * @notice Sends amount `amount` of ETH in proxy to SplitMain
   *  @dev payable reduces gas cost; no vulnerability to accidentally lock
   *  ETH introduced since fn call is restricted to SplitMain
   */
  function sendETHToMain() external payable onlySplitMain returns (uint256 amount) {
    amount = address(this).balance;
    address(splitMain).safeTransferETH(amount);
  }

  /**
   * @notice Sends amount `amount` of ERC20 `token` in proxy to SplitMain
   *  @dev payable reduces gas cost; no vulnerability to accidentally lock
   *  ETH introduced since fn call is restricted to SplitMain
   *  @param token Token to send
   */
  function sendERC20ToMain(ERC20 token) external payable onlySplitMain returns (uint256 amount) {
    amount = token.balanceOf(address(this));
    token.safeTransfer(address(splitMain), amount);
  }
}
