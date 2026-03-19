// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {LibClone} from "solady/utils/LibClone.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import "./ObolLidoSplit.sol";

/// @title ObolLidoSplitFactory
/// @author Obol
/// @notice A factory contract for cheaply deploying ObolLidoSplit.
/// @dev The address returned should be used to as reward address for Lido
contract ObolLidoSplitFactory {
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

  /// Emitted after lido split
  event CreateObolLidoSplit(address split);

  /// -----------------------------------------------------------------------
  /// storage
  /// -----------------------------------------------------------------------

  /// @dev lido split implementation
  ObolLidoSplit public immutable lidoSplitImpl;

  constructor(address _feeRecipient, uint256 _feeShare, ERC20 _stETH, ERC20 _wstETH) {
    lidoSplitImpl = new ObolLidoSplit(_feeRecipient, _feeShare, _stETH, _wstETH);
  }

  /// Creates a wrapper for splitWallet that transforms stETH token into
  /// wstETH
  /// @param splitWallet Address of the splitWallet to transfer wstETH to
  /// @return lidoSplit Address of the wrappper split
  function createSplit(address splitWallet) external returns (address lidoSplit) {
    if (splitWallet == address(0)) revert Invalid_Wallet();

    lidoSplit = address(lidoSplitImpl).clone(abi.encodePacked(splitWallet));

    emit CreateObolLidoSplit(lidoSplit);
  }
}
