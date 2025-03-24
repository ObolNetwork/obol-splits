// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {LibClone} from "solady/utils/LibClone.sol";
import {ObolRocketPoolRecipient} from "./ObolRocketPoolRecipient.sol";
import {IENSReverseRegistrar} from "../interfaces/IENSReverseRegistrar.sol";

contract ObolRocketPoolRecipientFactory {
  /// -----------------------------------------------------------------------
  /// libraries
  /// -----------------------------------------------------------------------
  using LibClone for address;

  /// -----------------------------------------------------------------------
  /// errors
  /// -----------------------------------------------------------------------
  /// Invalid number of recipients, must be 2
  error Invalid__Recipients();

  /// Thresholds must be positive
  error Invalid__ZeroThreshold();

  /// Invalid threshold at `index`; must be < 2^96
  /// @param threshold threshold of too-large threshold
  error Invalid__ThresholdTooLarge(uint256 threshold);

  /// Invalid address
  error Invalid__Address();

  /// -----------------------------------------------------------------------
  /// events
  /// -----------------------------------------------------------------------
  /// Emitted after a new ObolRocketPoolRecipient is deployed
  /// @param rp Address of newly created ObolRocketPoolRecipient clone
  /// @param recoveryAddress Address to recover non-ETH tokens to
  /// @param principalRecipient Address to distribute principal payment to
  /// @param rewardRecipient Address to distribute reward payment to
  /// @param threshold Absolute payment threshold for ObolRocketPoolRecipient first recipient
  /// (reward recipient has no threshold & receives all residual flows)
  event CreateObolRocketPoolRecipient(
    address indexed rp,
    address rpStorage,
    address recoveryAddress,
    address principalRecipient,
    address rewardRecipient,
    uint256 threshold
  );
  /// -----------------------------------------------------------------------
  /// storage
  /// -----------------------------------------------------------------------

  uint256 internal constant ADDRESS_BITS = 160;
  address internal constant ETH_ADDRESS = address(0);

  /// ObolRocketPoolRecipient implementation address
  ObolRocketPoolRecipient public immutable rpRecipientImplementation;

  address public immutable rpStorage;

  constructor(address _rpStorage, string memory _ensName, address _ensReverseRegistrar, address _ensOwner) {
    if (_rpStorage == address(0)) revert Invalid__Address();

    rpStorage = _rpStorage;

    rpRecipientImplementation = new ObolRocketPoolRecipient(_rpStorage);
    IENSReverseRegistrar(_ensReverseRegistrar).setName(_ensName);
    IENSReverseRegistrar(_ensReverseRegistrar).claim(_ensOwner);
  }

  /// -----------------------------------------------------------------------
  /// functions
  /// -----------------------------------------------------------------------

  /// -----------------------------------------------------------------------
  /// functions - public & external
  /// -----------------------------------------------------------------------
  function createObolRocketPoolRecipient(
    address recoveryAddress,
    address principalRecipient,
    address rewardRecipient,
    uint256 amountOfPrincipalStake
  ) external returns (ObolRocketPoolRecipient rpRecipient) {
    /// checks

    // ensure doesn't have address(0)
    if (principalRecipient == address(0) || rewardRecipient == address(0)) revert Invalid__Recipients();
    // ensure threshold isn't zero
    if (amountOfPrincipalStake == 0) revert Invalid__ZeroThreshold();
    // ensure threshold isn't too large
    if (amountOfPrincipalStake > type(uint96).max) revert Invalid__ThresholdTooLarge(amountOfPrincipalStake);

    /// effects
    uint256 principalData = (amountOfPrincipalStake << ADDRESS_BITS) | uint256(uint160(principalRecipient));
    uint256 rewardData = uint256(uint160(rewardRecipient));

    // would not exceed contract size limits
    // important to not reorder
    bytes memory data = abi.encodePacked(recoveryAddress, principalData, rewardData);

    rpRecipient = ObolRocketPoolRecipient(address(rpRecipientImplementation).clone(data));

    emit CreateObolRocketPoolRecipient(
      address(rpRecipient), rpStorage, recoveryAddress, principalRecipient, rewardRecipient, amountOfPrincipalStake
    );
  }
}
