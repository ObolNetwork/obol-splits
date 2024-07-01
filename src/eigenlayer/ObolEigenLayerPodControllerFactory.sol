// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ObolEigenLayerPodController} from "./ObolEigenLayerPodController.sol";
import {LibClone} from "solady/utils/LibClone.sol";

/// @title ObolEigenLayerFactory
/// @author Obol
/// @notice A factory contract for cheaply deploying ObolLidoEigenLayer.
/// @dev The address returned should be used to as the EigenPod address
contract ObolEigenLayerPodControllerFactory {
  error Invalid_Owner();
  error Invalid_WithdrawalAddress();
  error Invalid_DelegationManager();
  error Invalid_EigenPodManaager();
  error Invalid_WithdrawalRouter();

  using LibClone for address;

  event CreatePodController(address indexed controller, address indexed withdrawalAddress, address owner);

  ObolEigenLayerPodController public immutable controllerImplementation;

  constructor(
    address feeRecipient,
    uint256 feeShare,
    address delegationManager,
    address eigenPodManager,
    address withdrawalRouter
  ) {
    if (delegationManager == address(0)) revert Invalid_DelegationManager();
    if (eigenPodManager == address(0)) revert Invalid_EigenPodManaager();
    if (withdrawalRouter == address(0)) revert Invalid_WithdrawalRouter();

    controllerImplementation =
      new ObolEigenLayerPodController(feeRecipient, feeShare, delegationManager, eigenPodManager, withdrawalRouter);
    // initialize implementation
    controllerImplementation.initialize(feeRecipient, feeRecipient);
  }

  /// Creates a minimal proxy clone of implementation
  /// @param owner address of owner
  /// @param withdrawalAddress address of withdrawalAddress
  /// @return controller Deployed obol eigen layer controller
  function createPodController(address owner, address withdrawalAddress) external returns (address controller) {
    if (owner == address(0)) revert Invalid_Owner();
    if (withdrawalAddress == address(0)) revert Invalid_WithdrawalAddress();

    bytes32 salt = _createSalt(owner, withdrawalAddress);

    controller = address(controllerImplementation).cloneDeterministic("", salt);

    ObolEigenLayerPodController(controller).initialize(owner, withdrawalAddress);

    emit CreatePodController(controller, withdrawalAddress, owner);
  }

  /// Predict the controller address
  /// @param owner address of owner
  /// @param withdrawalAddress address to withdraw funds to
  function predictControllerAddress(address owner, address withdrawalAddress)
    external
    view
    returns (address controller)
  {
    bytes32 salt = _createSalt(owner, withdrawalAddress);
    controller = address(controllerImplementation).predictDeterministicAddress("", salt, address(this));
  }

  function _createSalt(address owner, address withdrawalAddress) internal pure returns (bytes32 salt) {
    return keccak256(abi.encode(owner, withdrawalAddress));
  }
}
