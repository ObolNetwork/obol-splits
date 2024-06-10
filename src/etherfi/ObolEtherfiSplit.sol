// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Clone} from "solady/utils/Clone.sol";
import {IweETH} from "src/interfaces/external/IweETH.sol";

import {BaseSplit} from "../base/BaseSplit.sol";

/// @title ObolEtherfiSplit
/// @author Obol
/// @notice A wrapper for 0xsplits/split-contracts SplitWallet that transforms
/// eEth token to weETH token because eEth is a rebasing token
/// @dev Wraps eETH to weETH and
contract ObolEtherfiSplit is BaseSplit {
  /// @notice eETH token
  ERC20 public immutable eETH;

  /// @notice weETH token
  ERC20 public immutable weETH;

  /// @notice Constructor
  /// @param _feeRecipient address to receive fee
  /// @param _feeShare fee share scaled by PERCENTAGE_SCALE
  /// @param _eETH eETH address
  /// @param _weETH weETH address
  constructor(address _feeRecipient, uint256 _feeShare, ERC20 _eETH, ERC20 _weETH) BaseSplit(_feeRecipient, _feeShare) {
    eETH = _eETH;
    weETH = _weETH;
  }

  function _beforeRescueFunds(address tokenAddress) internal view override {
    // we check weETH here so rescueFunds can't be used
    // to bypass fee
    if (tokenAddress == address(eETH) || tokenAddress == address(weETH)) revert Invalid_Address();
  }

  /// Wraps the current eETH token balance to weETH
  /// transfers the weETH balance to withdrawalAddress for distribution
  function _beforeDistribute() internal override returns (address tokenAddress, uint256 amount) {
    tokenAddress = address(weETH);

    // get current balance
    uint256 balance = eETH.balanceOf(address(this));
    // approve the weETH
    eETH.approve(address(weETH), balance);
    // wrap into wseth
    // we ignore the return value
    IweETH(address(weETH)).wrap(balance);
    // we use balanceOf here in case some weETH is stuck in the
    // contract we would be able to rescue it
    amount = ERC20(weETH).balanceOf(address(this));
  }
}
