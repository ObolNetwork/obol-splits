// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILiquidWaterfall {
  function balanceOf(address owner, uint256 id) external returns (uint256);
}
