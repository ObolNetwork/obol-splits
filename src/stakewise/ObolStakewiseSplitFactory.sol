// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {LibClone} from "solady/utils/LibClone.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import "./ObolStakewiseSplit.sol";

/// @title ObolStakewiseSplitFactory
/// @author Obol
/// @notice A factory contract for cheaply deploying ObolStakewiseSplit.
/// @dev The address returned should be used to as reward address for Stakewise
contract ObolStakewiseSplitFactory {
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

  /// Emitted after Stakewise split
  event CreateObolStakewiseSplit(address split);

  /// -----------------------------------------------------------------------
  /// storage
  /// -----------------------------------------------------------------------

  /// @dev Stakewise split implementation
  ObolStakewiseSplit public immutable stakewiseSplitImpl;

  constructor(address _feeRecipient, uint256 _feeShare) {
    stakewiseSplitImpl = new ObolStakewiseSplit(_feeRecipient, _feeShare);
  }

  /// Creates a wrapper for splitWallet that distributes Stakewise rewards
  /// @param splitWallet Address of the splitWallet to transfer vault tokens to
  /// @param vaultToken Address of the Stakewise Vault token
  /// @return stakewiseSplit Address of the wrappper split
  function createSplit(address splitWallet, address vaultToken) external returns (address stakewiseSplit) {
    if (splitWallet == address(0)) revert Invalid_Wallet();

    stakewiseSplit = address(stakewiseSplitImpl).clone(abi.encodePacked(splitWallet, vaultToken));

    emit CreateObolStakewiseSplit(stakewiseSplit);
  }
}
