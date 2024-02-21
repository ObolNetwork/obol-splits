// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {LibClone} from "solady/utils/LibClone.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import "./ObolEtherfiSplit.sol";

/// @title ObolEtherfiSplitFactory
/// @author Obol
/// @notice A factory contract for cheaply deploying ObolEtherfiSplit.
/// @dev The address returned should be used to as reward address for EtherFi
contract ObolEtherfiSplitFactory {
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

  /// Emitted after Etherfi split
  event CreateObolEtherfiSplit(address split);

  /// -----------------------------------------------------------------------
  /// storage
  /// -----------------------------------------------------------------------

  /// @dev Ethersfi split implementation
  ObolEtherfiSplit public immutable etherfiSplitImpl;

  constructor(address _feeRecipient, uint256 _feeShare, ERC20 _eETH, ERC20 _weETH) {
    etherfiSplitImpl = new ObolEtherfiSplit(_feeRecipient, _feeShare, _eETH, _weETH);
  }

  /// Creates a wrapper for splitWallet that transforms eETH token into
  /// weETH
  /// @param splitWallet Address of the splitWallet to transfer weETH to
  /// @return ethersfiSplit Address of the wrappper split
  function createSplit(address splitWallet) external returns (address ethersfiSplit) {
    if (splitWallet == address(0)) revert Invalid_Wallet();

    ethersfiSplit = address(etherfiSplitImpl).clone(abi.encodePacked(splitWallet));

    emit CreateObolEtherfiSplit(ethersfiSplit);
  }
}