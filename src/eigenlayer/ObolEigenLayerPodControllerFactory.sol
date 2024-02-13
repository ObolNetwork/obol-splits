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
  error Invalid_Split();
  error Invalid_DelegationManager();
  error Invalid_EigenPodManaager();
  error Invalid_WithdrawalRouter();

  using LibClone for address;

  event CreatePodController(address indexed controller, address indexed split, address owner);

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

    controllerImplementation.initialize(feeRecipient, feeRecipient);
  }

  /// Creates a minimal proxy clone of implementation
  /// @param owner address of owner
  /// @param split address of split
  /// @return controller Deployed obol eigen layer controller
  function createPodController(address owner, address split) external returns (address controller) {
    if (owner == address(0)) revert Invalid_Owner();
    if (split == address(0)) revert Invalid_Split();

    controller = address(controllerImplementation).clone("");

    ObolEigenLayerPodController(controller).initialize(owner, split);

    emit CreatePodController(controller, split, owner);
  }
}
