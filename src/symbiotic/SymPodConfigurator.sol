// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ISymPodConfigurator} from "src/interfaces/ISymPodConfigurator.sol";
import {Ownable} from "solady/auth/Ownable.sol";

contract SymPodConfigurator is ISymPodConfigurator, Ownable {
  /// @dev pause checkpoint index
  uint256 internal constant PAUSE_CHECKPOINT_INDEX = 0;

  /// @dev store pause configuration
  uint256 internal _pauseMap;

  constructor(address _owner) {}

  function pauseCheckPoint() external onlyOwner {

  }

  function unpauseCheckPoint() external onlyOwner {

  }

  function isCheckPointPaused() external returns (bool) {
    
  }
}
