// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

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
  /// -----------------------------------------------------------------------
  /// libraries
  /// -----------------------------------------------------------------------
  using SafeTransferLib for ERC20;

  /// -----------------------------------------------------------------------
  /// storage - cwia offsets
  /// -----------------------------------------------------------------------

  // stETH (address, 20 bytes),
  // 0; first item
  uint256 internal constant ST_ETH_ADDRESS_OFFSET = 0;
  // wstETH (address, 20 bytees)
  // 20 = st_eth_offset(0) + st_eth_address_size(address, 20 bytes)
  uint256 internal constant WST_ETH_ADDRESS_OFFSET = 20;
  // splitWallet (adress, 20 bytes)
  // 40 = wst_eth_offset(20) + wst_eth_size(address, 20 bytes)
  uint256 internal constant SPLIT_WALLET_ADDRESS_OFFSET = 40;

  constructor() {}

  /// Address of split wallet to send funds to to
  /// @dev equivalent to address public immutable splitWallet
  function splitWallet() public pure returns (address) {
    return _getArgAddress(SPLIT_WALLET_ADDRESS_OFFSET);
  }

  /// Address of stETH token
  /// @dev equivalent to address public immutable stETHAddress
  function stETHAddress() public pure returns (address) {
    return _getArgAddress(ST_ETH_ADDRESS_OFFSET);
  }

  /// Address of wstETH token
  /// @dev equivalent to address public immutable wstETHAddress
  function wstETHAddress() public pure returns (address) {
    return _getArgAddress(WST_ETH_ADDRESS_OFFSET);
  }

  /// Wraps the current stETH token balance to wstETH
  /// transfers the wstETH balance to splitWallet for distribution
  /// @return amount Amount of wstETH transferred to splitWallet
  function distribute() external returns (uint256 amount) {
    ERC20 stETH = ERC20(stETHAddress());
    ERC20 wstETH = ERC20(wstETHAddress());

    // get current balance
    uint256 balance = stETH.balanceOf(address(this));
    // approve the wstETH
    stETH.approve(address(wstETH), balance);
    // wrap into wseth
    amount = IwSTETH(address(wstETH)).wrap(balance);
    // transfer to split wallet
    ERC20(wstETH).safeTransfer(splitWallet(), amount);
  }
}
