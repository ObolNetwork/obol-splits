// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Clone} from "solady/utils/Clone.sol";
import {IwstETH} from "src/interfaces/external/IwstETH.sol";
import {BaseSplit} from "../base/BaseSplit.sol";

/// @title ObolLidoSplit
/// @author Obol
/// @notice A wrapper for 0xsplits/split-contracts SplitWallet that transforms
/// stETH token to wstETH token because stETH is a rebasing token
/// @dev Wraps stETH to wstETH and transfers to defined SplitWallet address
contract ObolLidoSplit is BaseSplit {
  /// @notice stETH token
  ERC20 public immutable stETH;

  /// @notice wstETH token
  ERC20 public immutable wstETH;

  /// @notice Constructor
  /// @param _feeRecipient address to receive fee
  /// @param _feeShare fee share scaled by PERCENTAGE_SCALE
  /// @param _stETH stETH address
  /// @param _wstETH wstETH address
  constructor(address _feeRecipient, uint256 _feeShare, ERC20 _stETH, ERC20 _wstETH)  BaseSplit(_feeRecipient, _feeShare) {
    stETH = _stETH;
    wstETH = _wstETH;
  }

  function _beforeRescueFunds(address tokenAddress) internal view override {
    // we check weETH here so rescueFunds can't be used
    // to bypass fee
    if (tokenAddress == address(stETH) || tokenAddress == address(wstETH)) revert Invalid_Address();
  }

  /// Wraps the current stETH token balance to wstETH
  /// transfers the wstETH balance to withdrawalAddress for distribution
  function _beforeDistribute() internal override returns (address tokenAddress, uint256 amount) {
    tokenAddress = address(wstETH);

    // get current balance
    uint256 balance = stETH.balanceOf(address(this));
    // approve the wstETH
    stETH.approve(address(wstETH), balance);
    // wrap into wstETH
    // we ignore the return value
    IwstETH(address(wstETH)).wrap(balance);
    // we use balanceOf here in case some wstETH is stuck in the
    // contract we would be able to rescue it
    amount = ERC20(wstETH).balanceOf(address(this));
  }
}
