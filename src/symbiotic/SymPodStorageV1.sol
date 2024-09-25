// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {ReentrancyGuard} from "openzeppelin/security/ReentrancyGuard.sol";
import {ERC4626} from "solady/tokens/ERC4626.sol";
import {ISymPod} from "src/interfaces/ISymPod.sol";

abstract contract SymPodStorageV1 is ERC4626, Initializable, ISymPod, ReentrancyGuard {
  /// @dev hardfork it supports
  string public HARDFORK;

  /// @dev total restaked amount in wei
  uint256 internal totalRestakedETH;

  /// @dev admin
  address public admin;

  /// @dev Address that receives withdrawn funds
  address public withdrawalAddress;

  /// @dev Address to recover tokens to
  address public recoveryAddress;

  /// @dev number of active validators
  uint64 public numberOfActiveValidators;

  /// @dev currrent checkpoint timestamp
  uint64 public currentCheckPointTimestamp;

  /// @dev last checkpoint timestamp
  uint64 public lastCheckpointTimestamp;

  /// @dev withdrawable execution layer ETH
  uint64 public withdrawableRestakedExecutionLayerGwei;

  /// @dev checkpoint
  Checkpoint currentCheckPoint;

  /// @dev pubKeyHash to validator info mapping
  mapping(uint256 validatorIndex => Validator validator) public validatorInfo;

  /// @dev withdrawal data
  mapping(bytes32 withdrawalKey => WithdrawalInfo info) public withdrawalQueue;

  /// @dev tracks exited validator balance per checkpoint timestamp
  mapping(uint64 => uint64) public checkpointBalanceExitedGwei;

  /// @notice slashing contract
  /// @dev Address of entity that can slash the pod i.e. withdraw from the pod
  /// without any delay
  address public slasher;

  modifier onlyAdmin() {
    if (msg.sender != admin) revert SymPod__Unauthorized();
    _;
  }
}
