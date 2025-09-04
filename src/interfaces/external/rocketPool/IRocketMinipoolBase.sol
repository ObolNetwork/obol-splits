// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRocketMinipoolBase {
  // IRocketMiniPoolDelegate
  function getEffectiveDelegate() external view returns (address);
}
