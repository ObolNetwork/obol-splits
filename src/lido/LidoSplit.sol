// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Clone} from "solady/utils/Clone.sol";

interface IwSTETH {
  function wrap(uint256 amount) external returns (uint256);
}

/// @title LidoSplit
/// @author Obol
/// @notice A wrapper for 0xsplits/split-contracts SplitWallet that transforms
/// stETH token to wstETH token because stETH is a rebasing token
/// @dev Wraps stETH to wstETH and transfers to defined SplitWallet address
contract LidoSplit is Clone {

  error Invalid_Address();
  
  /// -----------------------------------------------------------------------
  /// libraries
  /// -----------------------------------------------------------------------
  using SafeTransferLib for ERC20;
  using SafeTransferLib for address;

  address internal constant ETH_ADDRESS = address(0);

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

  constructor(ERC20 _stETH, ERC20 _wstETH) {
    stETH = _stETH;
    wstETH = _wstETH;
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
    amount = IwSTETH(address(wstETH)).wrap(balance);
    // transfer to split wallet
    ERC20(wstETH).safeTransfer(splitWallet(), amount);
  }

  /// @notice Rescue stuck ETH
  /// Uses token == address(0) to represent ETH
  /// @return balance Amount of ETH rescued
  function rescueFunds(address token) external returns (uint256 balance) {
    if (token == address(stETH)) revert Invalid_Address();  
    
    if (token == ETH_ADDRESS) {
      balance = address(this).balance;
      if (balance > 0) splitWallet().safeTransferETH(balance);
    } else {
      balance = ERC20(token).balanceOf(address(this));
      if (balance > 0) ERC20(token).transfer(splitWallet(), balance);
    }
  }
}
