// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {LibClone} from "solady/utils/LibClone.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import "./ObolEthersfiSplit.sol";

/// @title ObolEthersfiSplitFactory
/// @author Obol
/// @notice A factory contract for cheaply deploying ObolEthersfiSplit.
/// @dev The address returned should be used to as reward address for EthersFi
contract ObolEthersfiSplitFactory {
  /// -----------------------------------------------------------------------
  /// errors
  /// -----------------------------------------------------------------------

  /// Invalid wallet
  error Invalid_Wallet();

  /// -----------------------------------------------------------------------
  /// libraries
  /// -----------------------------------------------------------------------
  using LibClone for address;

  /// -----------------------------------------------------------------------
  /// events
  /// -----------------------------------------------------------------------

  /// Emitted after Ethersfi split
  event CreateObolEthersfiSplit(address split);

  /// -----------------------------------------------------------------------
  /// storage
  /// -----------------------------------------------------------------------

  /// @dev Ethersfi split implementation
  ObolEthersfiSplit public immutable ethersfiSplitImpl;

  constructor(address _feeRecipient, uint256 _feeShare, ERC20 _eETH, ERC20 _weETH) {
    ethersfiSplitImpl = new ObolEthersfiSplit(_feeRecipient, _feeShare, _eETH, _weETH);
  }

  /// Creates a wrapper for splitWallet that transforms eETH token into
  /// weETH
  /// @param splitWallet Address of the splitWallet to transfer weETH to
  /// @return ethersfiSplit Address of the wrappper split
  function createSplit(address splitWallet) external returns (address ethersfiSplit) {
    if (splitWallet == address(0)) revert Invalid_Wallet();

    ethersfiSplit = address(ethersfiSplitImpl).clone(abi.encodePacked(splitWallet));

    emit CreateObolEthersfiSplit(ethersfiSplit);
  }
}