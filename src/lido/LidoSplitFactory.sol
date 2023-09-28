// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

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

  /// @dev lido split implementation
  LidoSplit public immutable lidoSplitImpl;

  constructor(
    ERC20 _stETH,
    ERC20 _wstETH,
    address _nosRegistry, 
    address _etMotion
  ) {
    lidoSplitImpl = new LidoSplit(_stETH, _wstETH, _nosRegistry, _etMotion);
    // initialize implementation to prevent rogue
    // actor initialisation
    lidoSplitImpl.intialize(address(1));
  }

  /// Creates a wrapper for splitWallet that transforms stETH token into
  /// wstETH and can create ET motions
  /// @param splitWallet Address of the splitWallet to transfer wstETH to
  /// @return lidoSplit Address of the wrappper split
  function createSplit(address splitWallet, address owner) external returns (address lidoSplit) {
    if (splitWallet == address(0)) revert Invalid_Wallet();
    if (owner == address(0)) revert Invalid_Owner();

    lidoSplit = address(lidoSplitImpl).clone(abi.encodePacked(splitWallet));
    // intialize owner address
    LidoSplit(lidoSplit).intialize(owner);

    emit CreateLidoSplit(lidoSplit);
  }
}
