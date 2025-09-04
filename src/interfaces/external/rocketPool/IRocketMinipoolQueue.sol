// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRocketMinipoolQueue {
  function getTotalLength() external view returns (uint256);
  function getContainsLegacy() external view returns (bool);
  function getLength() external view returns (uint256);
  function getTotalCapacity() external view returns (uint256);
  function getEffectiveCapacity() external view returns (uint256);
  function getNextCapacityLegacy() external view returns (uint256);
  function enqueueMinipool(address _minipool) external;
  function dequeueMinipools(uint256 _maxToDequeue) external returns (address[] memory minipoolAddress);
  function getMinipoolAt(uint256 _index) external view returns (address);
  function getMinipoolPosition(address _minipool) external view returns (int256);
}
