// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {LibClone} from "solady/utils/LibClone.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import "./LidoSplit.sol";

/// @title LidoSplitFactory
/// @author Obol
/// @notice A factory contract for cheaply deploying LidoSplit.
/// @dev The address returned should be used to as reward address for Lido
contract LidoSplitFactory {
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
  event CreateLidoSplit(address split);

  /// -----------------------------------------------------------------------
  /// storage
  /// -----------------------------------------------------------------------

  /// @notice stETH token address
  ERC20 public immutable stETH;

  /// @notice wstETH token address
  ERC20 public immutable wstETH;

  /// @dev lido split implementation
  LidoSplit public immutable lidoSplitImpl;

  constructor(ERC20 _stETH, ERC20 _wstETH) {
    stETH = _stETH;
    wstETH = _wstETH;
    lidoSplitImpl = new LidoSplit();
  }

  /// Creates a wrapper for splitWallet that transforms stETH token into wstETH
  /// @param splitWallet Address of the splitWallet to transfer wstETH to
  /// @return lidoSplit Address of the wrappper split
  function createSplit(address splitWallet) external returns (address lidoSplit) {
    if (splitWallet == address(0)) revert Invalid_Wallet();

    lidoSplit = address(lidoSplitImpl).clone(abi.encodePacked(stETH, wstETH, splitWallet));

    emit CreateLidoSplit(lidoSplit);
  }
}
