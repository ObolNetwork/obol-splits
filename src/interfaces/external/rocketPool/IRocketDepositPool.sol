// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRocketDepositPool {
  function getBalance() external view returns (uint256);
  function getNodeBalance() external view returns (uint256);
  function getUserBalance() external view returns (int256);
  function getExcessBalance() external view returns (uint256);
  function deposit() external payable;
  function getMaximumDepositAmount() external view returns (uint256);
}
