// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Clone} from "solady/utils/Clone.sol";
import {IweETH} from "src/interfaces/IweETH.sol"; 

/// @title ObolEtherfiSplit
/// @author Obol
/// @notice A wrapper for 0xsplits/split-contracts SplitWallet that transforms
/// eEth token to weETH token because eEth is a rebasing token
/// @dev Wraps eETH to weETH and
contract ObolEtherfiSplit is Clone {
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

  /// @notice eETH token
  ERC20 public immutable eETH;

  /// @notice weETH token
  ERC20 public immutable weETH;

  /// @notice fee address
  address public immutable feeRecipient;

  /// @notice fee share
  uint256 public immutable feeShare;

  /// @notice Constructor
  /// @param _feeRecipient address to receive fee
  /// @param _feeShare fee share scaled by PERCENTAGE_SCALE
  /// @param _eETH eETH address
  /// @param _weETH weETH address
  constructor(address _feeRecipient, uint256 _feeShare, ERC20 _eETH, ERC20 _weETH) {
    if (_feeShare >= PERCENTAGE_SCALE) revert Invalid_FeeShare(_feeShare);
    if (_feeShare > 0 && _feeRecipient == address(0)) revert Invalid_FeeRecipient();

    feeRecipient = _feeRecipient;
    eETH = _eETH;
    weETH = _weETH;
    feeShare = _feeShare;
  }

/// Address of split wallet to send funds to to
  /// @dev equivalent to address public immutable splitWallet
  function splitWallet() public pure returns (address) {
    return _getArgAddress(SPLIT_WALLET_ADDRESS_OFFSET);
  }

 /// Wraps the current eETH token balance to weETH
  /// transfers the weETH balance to splitWallet for distribution
  /// @return amount Amount of weETH transferred to splitWallet
  function distribute() external returns (uint256 amount) {
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

    if (feeShare > 0) {
      uint256 fee = (amount * feeShare) / PERCENTAGE_SCALE;
      // transfer to split wallet
      // update amount to reflect fee charged
      ERC20(weETH).safeTransfer(splitWallet(), amount -= fee);
      // transfer to fee address
      ERC20(weETH).safeTransfer(feeRecipient, fee);
    } else {
      // transfer to split wallet
      ERC20(weETH).safeTransfer(splitWallet(), amount);
    }
  }

    /// @notice Rescue stuck ETH and tokens
  /// Uses token == address(0) to represent ETH
  /// @return balance Amount of ETH or tokens rescued
  function rescueFunds(address token) external returns (uint256 balance) {
    // we check weETH here so rescueFunds can't be used
    // to bypass fee
    if (token == address(eETH) || token == address(weETH)) revert Invalid_Address();

    if (token == ETH_ADDRESS) {
      balance = address(this).balance;
      if (balance > 0) splitWallet().safeTransferETH(balance);
    } else {
      balance = ERC20(token).balanceOf(address(this));
      if (balance > 0) ERC20(token).safeTransfer(splitWallet(), balance);
    }
  }
}
