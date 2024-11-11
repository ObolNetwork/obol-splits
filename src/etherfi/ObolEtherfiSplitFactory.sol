// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {LibClone} from "solady/utils/LibClone.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import "./ObolEtherfiSplit.sol";
import {BaseSplitFactory} from "../base/BaseSplitFactory.sol";

/// @title ObolEtherfiSplitFactory
/// @author Obol
/// @notice A factory contract for cheaply deploying ObolEtherfiSplit.
/// @dev The address returned should be used to as reward address for EtherFi
contract ObolEtherfiSplitFactory is BaseSplitFactory {
  /// -----------------------------------------------------------------------
  /// libraries
  /// -----------------------------------------------------------------------
  using LibClone for address;

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
  /// @dev Create a new collector
  /// @dev address(0) is used to represent ETH
  /// @param withdrawalAddress Address of the splitWallet to transfer weETH to
  /// @return collector Address of the wrapper split
  function createCollector(address, address withdrawalAddress) external override returns (address collector) {
    if (withdrawalAddress == address(0)) revert Invalid_Address();

    collector = address(etherfiSplitImpl).clone(abi.encodePacked(withdrawalAddress));

    emit CreateSplit(address(0), collector);
  }
}
