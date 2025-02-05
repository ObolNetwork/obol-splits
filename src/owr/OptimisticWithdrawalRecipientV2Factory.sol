// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {OptimisticWithdrawalRecipientV2} from "./OptimisticWithdrawalRecipientV2.sol";
import {IENSReverseRegistrar} from "../interfaces/IENSReverseRegistrar.sol";

/// @title OptimisticWithdrawalRecipientV2Factory
/// @author Obol
/// @notice A factory contract for deploying OptimisticWithdrawalRecipientV2.
contract OptimisticWithdrawalRecipientV2Factory {
  /// -----------------------------------------------------------------------
  /// errors
  /// -----------------------------------------------------------------------

  /// Some recipients are address(0)
  error Invalid__Recipients();

  /// Threshold must be positive
  error Invalid__ZeroThreshold();

  /// Threshold must be below 2048 ether
  error Invalid__ThresholdTooLarge();

  /// -----------------------------------------------------------------------
  /// events
  /// -----------------------------------------------------------------------

  /// Emitted after a new OptimisticWithdrawalRecipientV2 module is deployed
  /// @param owr Address of newly created OptimisticWithdrawalRecipientV2 instance
  /// @param owner Owner of newly created OptimisticWithdrawalRecipientV2 instance
  /// @param recoveryAddress Address to recover non-OWR tokens to
  /// @param principalRecipient Address to distribute principal payment to
  /// @param rewardRecipient Address to distribute reward payment to
  /// @param principalThreshold Principal vs rewards classification threshold
  event CreateOWRecipient(
    address indexed owr,
    address indexed owner,
    address recoveryAddress,
    address principalRecipient,
    address rewardRecipient,
    uint256 principalThreshold
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

  /// @param _ensName ENS name to register
  /// @param _ensReverseRegistrar ENS reverse registrar address
  /// @param _ensOwner ENS owner address
  /// @param _consolidationSystemContract Consolidation system contract address
  /// @param _withdrawalSystemContract Withdrawal system contract address
  /// @param _depositSystemContract Deposit system contract address
  /// @dev System contracts are expected to be deployed at:
  ///      Consolidation: 0x00431F263cE400f4455c2dCf564e53007Ca4bbBb
  ///      https://github.com/ethereum/EIPs/blob/d96625a4dcbbe2572fa006f062bd02b4582eefd5/EIPS/eip-7251.md#constants
  ///      Withdrawal: 0x0c15F14308530b7CDB8460094BbB9cC28b9AaaAA
  ///      https://github.com/ethereum/EIPs/blob/d96625a4dcbbe2572fa006f062bd02b4582eefd5/EIPS/eip-7002.md#configuration
  ///      Deposit Holesky/Devnet: 0x4242424242424242424242424242424242424242
  ///      Deposit Sepolia: 0x7f02C3E3c98b133055B8B348B2Ac625669Ed295D
  ///      Deposit Mainnet: 0x00000000219ab540356cBB839Cbe05303d7705Fa
  constructor(
    string memory _ensName,
    address _ensReverseRegistrar,
    address _ensOwner,
    address _consolidationSystemContract,
    address _withdrawalSystemContract,
    address _depositSystemContract
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

  /// Create a new OptimisticWithdrawalRecipientV2 instance
  /// @param recoveryAddress Address to recover tokens to
  /// If this address is 0x0, recovery of unrelated tokens can be completed by
  /// either the principal or reward recipients. If this address is set, only
  /// this address can recover ERC20 tokens allocated to the OWRV2 contract.
  /// @param principalRecipient Address to distribute principal payments to
  /// @param rewardRecipient Address to distribute reward payments to
  /// @param principalThreshold Principal vs rewards classification threshold
  /// @param owner Owner of the new OptimisticWithdrawalRecipientV2 instance
  /// @return owr Address of the new OptimisticWithdrawalRecipientV2 instance
  function createOWRecipient(
    address recoveryAddress,
    address principalRecipient,
    address rewardRecipient,
    uint256 principalThreshold,
    address owner
  ) external returns (OptimisticWithdrawalRecipientV2 owr) {
    if (principalRecipient == address(0) || rewardRecipient == address(0)) revert Invalid__Recipients();
    if (principalThreshold == 0) revert Invalid__ZeroThreshold();
    if (principalThreshold > 2048 ether) revert Invalid__ThresholdTooLarge();

    owr = new OptimisticWithdrawalRecipientV2(
      consolidationSystemContract,
      withdrawalSystemContract,
      depositSystemContract,
      recoveryAddress,
      principalRecipient,
      rewardRecipient,
      principalThreshold
    );
    owr.initialize(owner);

    emit CreateOWRecipient(
      address(owr),
      owner,
      recoveryAddress,
      principalRecipient,
      rewardRecipient,
      principalThreshold
    );
  }
}
