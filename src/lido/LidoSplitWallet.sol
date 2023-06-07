// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {ISplitMain} from './interfaces/ISplitMain.sol';
import {IwSTETH} from '../interfaces/IwSTETH.sol';
import {ERC20} from '@rari-capital/solmate/src/tokens/ERC20.sol';
import {SafeTransferLib} from '@rari-capital/solmate/src/utils/SafeTransferLib.sol';

/**
 * ERRORS
 */

/// @notice Unauthorized sender
error Unauthorized();

/**
 * @title LidoSplitWallet
 * @author Obol
 * @notice The implementation logic for `SplitProxy`.
 * @dev `SplitProxy` handles `receive()` itself to avoid the gas cost with `DELEGATECALL`.
 */
contract LidoSplitWallet {
  using SafeTransferLib for address;
  using SafeTransferLib for ERC20;

  /**
   * EVENTS
   */

  /** @notice emitted after each successful ETH transfer to proxy
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
  ISplitMain public immutable splitMain;

  /// @notice stETH token address
  ERC20 public immutable stETH;

  /// @notice wstETH token address
  ERC20 public immutable wstETH;

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

  constructor(ERC20 _stETH, ERC20 _wstETH) {
    stETH = _stETH;
    wstETH = _wstETH;
    splitMain = ISplitMain(msg.sender);
  }

  /**
   * FUNCTIONS - PUBLIC & EXTERNAL
   */

  /** @notice Sends amount `amount` of ETH in proxy to SplitMain
   *  @dev payable reduces gas cost; no vulnerability to accidentally lock
   *  ETH introduced since fn call is restricted to SplitMain
   *  @return amount Amount sent
   */
  function sendETHToMain() external payable onlySplitMain() returns(uint256 amount) {
    amount = address(this).balance;
    address(splitMain).safeTransferETH(amount);
  }

  /** @notice Sends amount `amount` of ERC20 `token` in proxy to SplitMain
   *  @dev payable reduces gas cost; no vulnerability to accidentally lock
   *  ETH introduced since fn call is restricted to SplitMain
   *  @param token Token to send
   *  @return amount Amount sent
   */
  function sendERC20ToMain(ERC20 /**token*/)
    external
    payable
    onlySplitMain()
    returns(uint256 amount)
  {
    // approve the wstETH
    uint256 balance = stETH.balanceOf(address(this));
    stETH.approve(address(wstETH), balance);
    amount = IwSTETH(address(wstETH)).wrap(balance);
    ERC20(wstETH).safeTransfer(address(splitMain), amount);
  }
}