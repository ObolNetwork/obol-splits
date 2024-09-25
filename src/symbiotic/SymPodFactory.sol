// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ISymPodFactory} from "src/interfaces/ISymPodFactory.sol";
import {SymPod} from "src/symbiotic/SymPod.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {BeaconProxy} from "openzeppelin/proxy/beacon/BeaconProxy.sol";
import {Create2} from "openzeppelin/utils/Create2.sol";

/// @title SymPodFactory
/// @author Obol
/// @notice A factory contract for cheaply deploying SymPod
contract SymPodFactory is ISymPodFactory {
  /// @notice symPoad implementation beacon
  address public immutable symPodBeacon;

  /// @dev number of address bits
  uint256 internal constant ADDRESS_BITS = 160;

  /// -----------------------------------------------------------------------
  /// libraries
  /// -----------------------------------------------------------------------

  using LibClone for address;

  /// -----------------------------------------------------------------------
  /// storage
  /// -----------------------------------------------------------------------

  constructor(address _symPodBeacon) {
    symPodBeacon = _symPodBeacon;
  }

  /// Create a new SymPod clone
  /// @param admin Address to perform admin duties on SymPod
  /// @param withdrawalAddress Address to receive principal + rewards
  /// @param recoveryRecipient Address to recover tokens to
  function createSymPod(address admin, address withdrawalAddress, address recoveryRecipient)
    external
    returns (address symPod)
  {
    /// checks

    if (admin == address(0)) revert SymPodFactory__InvalidAdmin();
    if (withdrawalAddress == address(0)) revert SymPodFactory__InvalidWithdrawalRecipient();
    if (recoveryRecipient == address(0)) revert SymPodFactory__InvalidRecoveryRecipient();

    bytes32 salt = _createSalt(admin, withdrawalAddress, recoveryRecipient);

    symPod = Create2.deploy(
      0,
      salt,
      abi.encodePacked(
        type(BeaconProxy).creationCode,
        abi.encode(
          symPodBeacon,
          abi.encodeWithSignature("initialize(address,address,address)", admin, withdrawalAddress, recoveryRecipient)
        )
      )
    );

    emit CreateSymPod(symPod, admin, withdrawalAddress, recoveryRecipient);
  }

  /// @notice Predict SymPod address
  /// @param admin principal address to receive principal stake
  /// @param withdrawalAddress reward addresss to receive rewards
  /// @param recoveryRecipient recovery address
  function predictSymPodAddress(address admin, address withdrawalAddress, address recoveryRecipient)
    external
    view
    returns (address symPod)
  {
    bytes32 salt = _createSalt(admin, withdrawalAddress, recoveryRecipient);
    symPod = Create2.computeAddress(
      salt,
      keccak256(
        abi.encodePacked(
          type(BeaconProxy).creationCode,
          abi.encode(
            symPodBeacon,
            abi.encodeWithSignature("initialize(address,address,address)", admin, withdrawalAddress, recoveryRecipient)
          )
        )
      )
    );
  }

  /// @dev creates salt
  function _createSalt(address admin, address withdrawalAddress, address recoveryRecipient)
    internal
    pure
    returns (bytes32 salt)
  {
    // important to not reorder
    bytes memory data = abi.encodePacked(admin, withdrawalAddress, recoveryRecipient);
    salt = keccak256(data);
  }
}
