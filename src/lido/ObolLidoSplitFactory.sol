// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {LibClone} from "solady/utils/LibClone.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {BaseSplitFactory} from "../base/BaseSplitFactory.sol";
import "./ObolLidoSplit.sol";

/// @title ObolLidoSplitFactory
/// @author Obol
/// @notice A factory contract for cheaply deploying ObolLidoSplit.
/// @dev The address returned should be used to as reward address for Lido
contract ObolLidoSplitFactory is BaseSplitFactory {

  /// -----------------------------------------------------------------------
  /// libraries
  /// -----------------------------------------------------------------------
  using LibClone for address;

  /// -----------------------------------------------------------------------
  /// storage
  /// -----------------------------------------------------------------------

  /// @dev lido split implementation
  ObolLidoSplit public immutable lidoSplitImpl;

  constructor(address _feeRecipient, uint256 _feeShare, ERC20 _stETH, ERC20 _wstETH) {
    lidoSplitImpl = new ObolLidoSplit(_feeRecipient, _feeShare, _stETH, _wstETH);
  }

  // Creates a wrapper for splitWallet that transforms stETH token into
  /// wstETH
  /// @dev Create a new collector
  /// @dev address(0) is used to represent ETH
  /// @param withdrawalAddress Address of the splitWallet to transfer wstETH to
  /// @return collector Address of the wrappper split
  function createCollector(address, address withdrawalAddress) external override returns (address collector) {
    if (withdrawalAddress == address(0)) revert Invalid_Address();

    collector = address(lidoSplitImpl).clone(abi.encodePacked(withdrawalAddress));

    emit CreateSplit(address(0), collector);
  }
}
