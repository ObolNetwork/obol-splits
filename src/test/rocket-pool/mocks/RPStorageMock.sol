// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

contract RPStorageMock {
  address public minipoolManager;

  function setMinipoolManager(address _minipoolManager) external {
    minipoolManager = _minipoolManager;
  }

  function getAddress(bytes32) external view returns (address) {
    return minipoolManager;
  }
}
