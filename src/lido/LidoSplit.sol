// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Clone} from "solady/utils/Clone.sol";
import {IwstETH} from "src/interfaces/IwstETH.sol";

/// @title LidoSplit
/// @author Obol
/// @notice A wrapper for 0xsplits/split-contracts SplitWallet that transforms
/// stETH token to wstETH token because stETH is a rebasing token
/// @dev Wraps stETH to wstETH and transfers to defined SplitWallet address
contract LidoSplit is Clone {
  error Invalid_Address();
  error Invalid_FeeShare(uint256 fee);
  error Invalid_FeeRecipient();

  /// -----------------------------------------------------------------------
  /// libraries
  /// -----------------------------------------------------------------------
  using SafeTransferLib for ERC20;
  using SafeTransferLib for address;

  address internal constant ETH_ADDRESS = address(0);
  uint256 internal constant PERCENTAGE_SCALE = 1e5;

  /// -----------------------------------------------------------------------
  /// storage - cwia offsets
  /// -----------------------------------------------------------------------

  // splitWallet (adress, 20 bytes)
  // 0; first item
  uint256 internal constant SPLIT_WALLET_ADDRESS_OFFSET = 0;

  /// -----------------------------------------------------------------------
  /// storage
  /// -----------------------------------------------------------------------

  /// @notice stETH token
  ERC20 public immutable stETH;

  /// @notice wstETH token
  ERC20 public immutable wstETH;

  /// @notice fee address
  address public immutable feeRecipient;

  /// @notice fee share
  uint256 public immutable feeShare;

  /// @notice Constructor
  /// @param _feeRecipient address to receive fee
  /// @param _feeShare fee share scaled by PERCENTAGE_SCALE
  /// @param _stETH stETH address
  /// @param _wstETH wstETH address
  constructor(address _feeRecipient, uint256 _feeShare, ERC20 _stETH, ERC20 _wstETH) {
    if (_feeShare >= PERCENTAGE_SCALE) revert Invalid_FeeShare(_feeShare);
    if (_feeShare > 0 && _feeRecipient == address(0)) revert Invalid_FeeRecipient();

    feeRecipient = _feeRecipient;
    stETH = _stETH;
    wstETH = _wstETH;
    feeShare = _feeShare;
  }

  /// Address of split wallet to send funds to to
  /// @dev equivalent to address public immutable splitWallet
  function splitWallet() public pure returns (address) {
    return _getArgAddress(SPLIT_WALLET_ADDRESS_OFFSET);
  }

  /// Wraps the current stETH token balance to wstETH
  /// transfers the wstETH balance to splitWallet for distribution
  /// @return amount Amount of wstETH transferred to splitWallet
  function distribute() external returns (uint256 amount) {
    // get current balance
    uint256 balance = stETH.balanceOf(address(this));
    // approve the wstETH
    stETH.approve(address(wstETH), balance);
    // wrap into wseth
    // we ignore the return value
    IwstETH(address(wstETH)).wrap(balance);
    // we use balanceOf here in case some wstETH is stuck in the
    // contract we would be able to rescue it
    amount = ERC20(wstETH).balanceOf(address(this));

    if (feeShare > 0) {
      uint256 fee = (amount * feeShare) / PERCENTAGE_SCALE;
      // transfer to split wallet
      // update amount to reflect fee charged
      ERC20(wstETH).safeTransfer(splitWallet(), amount -= fee);
      // transfer to fee address
      ERC20(wstETH).safeTransfer(feeRecipient, fee);
    } else {
      // transfer to split wallet
      ERC20(wstETH).safeTransfer(splitWallet(), amount);
    }
  }

  /// @notice Rescue stuck ETH and tokens
  /// Uses token == address(0) to represent ETH
  /// @return balance Amount of ETH or tokens rescued
  function rescueFunds(address token) external returns (uint256 balance) {
    // we check wstETH here so rescueFunds can't be used
    // to bypass fee
    if (token == address(stETH) || token == address(wstETH)) revert Invalid_Address();

    if (token == ETH_ADDRESS) {
      balance = address(this).balance;
      if (balance > 0) splitWallet().safeTransferETH(balance);
    } else {
      balance = ERC20(token).balanceOf(address(this));
      if (balance > 0) ERC20(token).safeTransfer(splitWallet(), balance);
    }
  }
}
