// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Clone} from "solady/utils/Clone.sol";

/// @author Obol
/// @notice A wrapper for 0xsplits/split-contracts SplitWallet that transforms
/// @dev Transfers Stakewise vault token to defined SplitWallet address
contract ObolStakewiseSplit is Clone {
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

  /// @notice Stakewise vault token token
  ERC20 public immutable vaultToken;

  /// @notice fee address
  address public immutable feeRecipient;

  /// @notice fee share
  uint256 public immutable feeShare;

  /// @notice Constructor
  /// @param _feeRecipient address to receive fee
  /// @param _feeShare fee share scaled by PERCENTAGE_SCALE
  /// @param _vaultToken Stakewise vault token token
  constructor(address _feeRecipient, uint256 _feeShare, ERC20 _vaultToken) {
    if (_feeShare >= PERCENTAGE_SCALE) revert Invalid_FeeShare(_feeShare);
    if (_feeShare > 0 && _feeRecipient == address(0)) revert Invalid_FeeRecipient();

    feeRecipient = _feeRecipient;
    vaultToken = _vaultToken;
    feeShare = _feeShare;
  }

  /// Address of split wallet to send funds to to
  /// @dev equivalent to address public immutable splitWallet
  function splitWallet() public pure returns (address) {
    return _getArgAddress(SPLIT_WALLET_ADDRESS_OFFSET);
  }

  function distribute() external returns (uint256 amount) {}

  function rescueFunds(address token) external returns (uint256 balance) {}
}
