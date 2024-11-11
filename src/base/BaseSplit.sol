// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Clone} from "solady/utils/Clone.sol";

abstract contract BaseSplit is Clone {
  error Invalid_Address();
  error Invalid_FeeShare(uint256 val);
  error Invalid_FeeRecipient();

  /// -----------------------------------------------------------------------
  /// libraries
  /// -----------------------------------------------------------------------
  using SafeTransferLib for ERC20;
  using SafeTransferLib for address;

  address internal constant ETH_ADDRESS = address(0);
  uint256 internal constant PERCENTAGE_SCALE = 1e5;

  /// @notice fee share
  uint256 public immutable feeShare;

  /// @notice fee address
  address public immutable feeRecipient;

  // withdrawal (adress, 20 bytes)
  // 0; first item
  uint256 internal constant WITHDRAWAL_ADDRESS_OFFSET = 0;
  // 20 = withdrawalAddress_offset (0) + withdrawalAddress_size (address, 20 bytes)
  uint256 internal constant TOKEN_ADDRESS_OFFSET = 20;

  constructor(address _feeRecipient, uint256 _feeShare) {
    if (_feeShare >= PERCENTAGE_SCALE) revert Invalid_FeeShare(_feeShare);
    if (_feeShare > 0 && _feeRecipient == address(0)) revert Invalid_FeeRecipient();

    feeShare = _feeShare;
    feeRecipient = _feeRecipient;
  }

  /// -----------------------------------------------------------------------
  /// View
  /// -----------------------------------------------------------------------

  /// Address to send funds to to
  /// @dev equivalent to address public immutable withdrawalAddress
  function withdrawalAddress() public pure returns (address) {
    return _getArgAddress(WITHDRAWAL_ADDRESS_OFFSET);
  }

  /// Token address
  /// @dev equivalent to address public immutable token
  function token() public pure virtual returns (address) {
    return _getArgAddress(TOKEN_ADDRESS_OFFSET);
  }

  /// -----------------------------------------------------------------------
  /// Public
  /// -----------------------------------------------------------------------

  /// @notice Rescue stuck ETH and tokens
  /// Uses token == address(0) to represent ETH
  /// @return balance Amount of ETH or tokens rescued
  function rescueFunds(address tokenAddress) external virtual returns (uint256 balance) {
    _beforeRescueFunds(tokenAddress);

    if (tokenAddress == ETH_ADDRESS) {
      balance = address(this).balance;
      if (balance > 0) withdrawalAddress().safeTransferETH(balance);
    } else {
      balance = ERC20(tokenAddress).balanceOf(address(this));
      if (balance > 0) ERC20(tokenAddress).safeTransfer(withdrawalAddress(), balance);
    }
  }

  /// @notice distribute funds to withdrawal address
  function distribute() external virtual returns (uint256) {
    (address tokenAddress, uint256 amount) = _beforeDistribute();

    if (feeShare > 0) {
      uint256 fee = (amount * feeShare) / PERCENTAGE_SCALE;
      _transfer(tokenAddress, feeRecipient, fee);
      _transfer(tokenAddress, withdrawalAddress(), amount -= fee);
    } else {
      _transfer(tokenAddress, withdrawalAddress(), amount);
    }

    return amount;
  }

  /// -----------------------------------------------------------------------
  /// Internal
  /// -----------------------------------------------------------------------

  function _beforeRescueFunds(address tokenAddress) internal virtual;

  function _beforeDistribute() internal virtual returns (address tokenAddress, uint256 amount);

  function _transfer(address tokenAddress, address receiver, uint256 amount) internal {
    if (tokenAddress == ETH_ADDRESS) receiver.safeTransferETH(amount);
    else ERC20(tokenAddress).safeTransfer(receiver, amount);
  }
}
