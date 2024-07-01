// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Clone} from "solady/utils/Clone.sol";
import {BaseSplit} from "../base/BaseSplit.sol";

/// @title ObolCollector
/// @author Obol
/// @notice An contract used to receive and distribute rewards minus fees
contract ObolCollector is BaseSplit {
  constructor(address _feeRecipient, uint256 _feeShare) BaseSplit(_feeRecipient, _feeShare) {}

  function _beforeRescueFunds(address tokenAddress) internal pure override {
    // prevent bypass
    if (tokenAddress == token()) revert Invalid_Address();
  }

  function _beforeDistribute() internal view override returns (address tokenAddress, uint256 amount) {
    tokenAddress = token();

    if (tokenAddress == ETH_ADDRESS) amount = address(this).balance;
    else amount = ERC20(tokenAddress).balanceOf(address(this));
  }
}
