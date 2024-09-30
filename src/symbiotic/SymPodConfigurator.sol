// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ISymPodConfigurator} from "src/interfaces/ISymPodConfigurator.sol";
import {Ownable} from "solady/auth/Ownable.sol";


/// @title SymPodConfigurator
/// @author Obol
/// @notice Provides configuration settings for a SymPod
contract SymPodConfigurator is ISymPodConfigurator, Ownable {
  /// @notice Emitted on pause
  /// @param sender sender
  /// @param index index paused
  event Paused(address sender, uint256 index, uint256 map);

  /// @notice Emitted on unpause
  event Unpaused(address sender, uint256 index, uint256 map);

  /// @dev pause checkpoint index
  uint8 internal constant CHECKPOINT_INDEX = 0;
  /// @dev withdrawal index
  uint8 internal constant WITHDRAWAL_INDEX = 1;

  /// @dev store pause configuration
  uint256 internal _pauseMap;

  constructor(address _owner) {
    _initializeOwner(_owner);
  }

  function pauseCheckPoint() external onlyOwner {
    _pause(CHECKPOINT_INDEX);
  }

  /// @dev Returns if Checkpoint is paused or not
  function unpauseCheckPoint() external onlyOwner {
    _unpause(CHECKPOINT_INDEX);
  }

  /// @notice Pause SymPod withdrawals
  function pauseWithdrawals() external onlyOwner {
    _pause(WITHDRAWAL_INDEX);
  }

  /// @notice UnPause SymPod withdrawals
  function unpauseWithdrawals() external onlyOwner {
    _unpause(WITHDRAWAL_INDEX);
  }

  function paused(uint256 index) public view returns (bool) {
    uint256 mask = 1 << index;
    return ((_pauseMap & mask) != 0);
  }
  
  /// @dev Returns if Checkpoint is paused or not
  function isCheckPointPaused() external view returns (bool isPaused) {
    isPaused = paused(CHECKPOINT_INDEX);
  }

  /// @notice Returns if SymPod withdrawals are paused
  function isWithdrawalsPaused() external view returns (bool isPaused) {
    isPaused = paused(WITHDRAWAL_INDEX);
  }
  
  function _pause(uint8 index) internal {
    uint256 mask = 1 << (index & 0xff);
    // Write to Storage
    _pauseMap |= mask;

    emit Paused(msg.sender, index, _pauseMap);
  }

  function _unpause(uint8 index) internal {
    uint256 mask = 1 << (index & 0xff);
    // Write to Storage
    _pauseMap &= ~mask;

    emit Unpaused(msg.sender, index, _pauseMap);
  }
}
