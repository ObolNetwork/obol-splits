// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IwstETH {
  function wrap(uint256 amount) external returns (uint256);
  function getWstETHByStETH(uint256 _stETHAmount) external view returns (uint256);
}
