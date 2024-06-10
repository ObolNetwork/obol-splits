// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IweETH {
  function wrap(uint256 _eETHAmount) external returns (uint256);
  function getEETHByWeETH(uint256 _weETHAmount) external view returns (uint256);
  function getWeETHByeETH(uint256 _eETHAmount) external view returns (uint256);
  function eETH() external view returns (address);
}
