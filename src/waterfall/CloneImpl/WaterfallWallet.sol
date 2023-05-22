// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.13;

import {ISplitMain} from './interfaces/ISplitMain.sol';
import {ERC20} from '@rari-capital/solmate/src/tokens/ERC20.sol';
import {SafeTransferLib} from '@rari-capital/solmate/src/utils/SafeTransferLib.sol';

/**
 * ERRORS
 */

/// @notice Unauthorized sender
error Unauthorized();

/**
 * @title WaterfallWallet
 * @author Obol <security@obol.tech>
 * @notice The implementation logic for `WaterfallWallet`.
 * @dev `WaterfallWalletProxy` handles `receive()` itself to avoid the gas cost with `DELEGATECALL`.
 */
contract WaterfallWallet {
  using SafeTransferLib for address;
  using SafeTransferLib for ERC20;

  /**
   * STORAGE
   */

  /**
   * STORAGE - CONSTANTS & IMMUTABLES
   */

  /// @notice address of SplitMain for split distributions & EOA/SC withdrawals
  ISplitMain public immutable splitMain;

  /**
   * MODIFIERS
   */

  /// @notice Reverts if the sender isn't SplitMain
  modifier onlyOwner() {
    // checks the liquidCloneImpl for the owner of the Id
    if (msg.sender != address(splitMain)) revert Unauthorized();
    _;
  }

  /**
   * CONSTRUCTOR
   */
  // use clone with args and read from there
  function initializer(address liquidWaterfallClone, uint256 tokenId) {
    splitMain = ISplitMain(msg.sender);
  }

  /**
   * FUNCTIONS - PUBLIC & EXTERNAL
   */

  /** @notice Sends amount `amount` of ETH in proxy to SplitMain
   *  @dev payable reduces gas cost; no vulnerability to accidentally lock
   *  ETH introduced since fn call is restricted to SplitMain
   *  @param amount Amount to send
   */
  function sendETHToMain(uint256 amount) external payable onlySplitMain() {
    address(splitMain).safeTransferETH(amount);
  }

  /** @notice Sends amount `amount` of ERC20 `token` in proxy to SplitMain
   *  @dev payable reduces gas cost; no vulnerability to accidentally lock
   *  ETH introduced since fn call is restricted to SplitMain
   *  @param token Token to send
   *  @param amount Amount to send
   */
  function sendERC20ToMain(ERC20 token, uint256 amount)
    external
    payable
    onlySplitMain()
  {
    token.safeTransfer(address(splitMain), amount);
  }

}