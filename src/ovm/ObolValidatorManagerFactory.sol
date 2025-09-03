// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ObolValidatorManager} from "./ObolValidatorManager.sol";
import {IENSReverseRegistrar} from "../interfaces/IENSReverseRegistrar.sol";

/// @title ObolValidatorManagerFactory
/// @author Obol
/// @notice A factory contract for deploying ObolValidatorManager.
contract ObolValidatorManagerFactory {
  /// -----------------------------------------------------------------------
  /// errors
  /// -----------------------------------------------------------------------

  /// Owner cannot be address(0)
  error Invalid_Owner();

  /// Some recipients are address(0)
  error Invalid__Recipients();

  /// Threshold must be positive
  error Invalid__ZeroThreshold();

  /// Threshold must be below 2048 ether
  error Invalid__ThresholdTooLarge();

  /// -----------------------------------------------------------------------
  /// events
  /// -----------------------------------------------------------------------

  /// Emitted after a new ObolValidatorManager instance is deployed
  /// @param ovm Address of newly created ObolValidatorManager instance
  /// @param owner Owner of newly created ObolValidatorManager instance
  /// @param principalRecipient Address to distribute principal payment to
  /// @param rewardRecipient Address to distribute reward payment to
  /// @param principalThreshold Principal vs rewards classification threshold (gwei)
  event CreateObolValidatorManager(
    address indexed ovm,
    address indexed owner,
    address principalRecipient,
    address rewardRecipient,
    uint64 principalThreshold
  );

  /// -----------------------------------------------------------------------
  /// storage - immutable
  /// -----------------------------------------------------------------------

  address public immutable consolidationSystemContract;
  address public immutable withdrawalSystemContract;
  address public immutable depositSystemContract;

  /// -----------------------------------------------------------------------
  /// constructor
  /// -----------------------------------------------------------------------

  /// @param _consolidationSystemContract Consolidation system contract address
  /// @param _withdrawalSystemContract Withdrawal system contract address
  /// @param _depositSystemContract Deposit system contract address
  /// @param _ensName ENS name to register
  /// @param _ensReverseRegistrar ENS reverse registrar address
  /// @param _ensOwner ENS owner address
  constructor(
    address _consolidationSystemContract,
    address _withdrawalSystemContract,
    address _depositSystemContract,
    string memory _ensName,
    address _ensReverseRegistrar,
    address _ensOwner
  ) {
    consolidationSystemContract = _consolidationSystemContract;
    withdrawalSystemContract = _withdrawalSystemContract;
    depositSystemContract = _depositSystemContract;

    IENSReverseRegistrar(_ensReverseRegistrar).setName(_ensName);
    IENSReverseRegistrar(_ensReverseRegistrar).claim(_ensOwner);
  }

  /// -----------------------------------------------------------------------
  /// functions
  /// -----------------------------------------------------------------------

  /// -----------------------------------------------------------------------
  /// functions - public & external
  /// -----------------------------------------------------------------------

  /// Create a new ObolValidatorManager instance
  /// @param owner Owner of the new ObolValidatorManager instance
  /// @param principalRecipient Address to distribute principal payments to
  /// @param rewardRecipient Address to distribute reward payments to
  /// @param principalThreshold Principal vs rewards classification threshold (gwei),
  ///                           the recommended value is 16000000000 (16 gwei).
  /// @return ovm Address of the new ObolValidatorManager instance
  function createObolValidatorManager(
    address owner,
    address principalRecipient,
    address rewardRecipient,
    uint64 principalThreshold
  ) external returns (ObolValidatorManager ovm) {
    if (owner == address(0)) revert Invalid_Owner();
    if (principalRecipient == address(0) || rewardRecipient == address(0)) revert Invalid__Recipients();
    if (principalThreshold == 0) revert Invalid__ZeroThreshold();
    if (principalThreshold > 2048 * 1e9) revert Invalid__ThresholdTooLarge();

    ovm = new ObolValidatorManager(
      consolidationSystemContract,
      withdrawalSystemContract,
      depositSystemContract,
      owner,
      principalRecipient,
      rewardRecipient,
      principalThreshold
    );

    emit CreateObolValidatorManager(address(ovm), owner, principalRecipient, rewardRecipient, principalThreshold);
  }
}
