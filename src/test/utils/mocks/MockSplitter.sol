// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import {ISplitMain} from "../../../Splitter.sol";

contract MockSplitter is ISplitMain {
  struct SplitData {
    address[] recipients;
    uint32[] percentAllocations;
    uint32 distributorFee;
    address controller;
  }

  SplitData[] public splitData;

  function createSplit(
    address[] calldata accounts,
    uint32[] calldata percentAllocations,
    uint32 distributorFee,
    address controller
  ) external returns (address) {
    SplitData memory data = SplitData(accounts, percentAllocations, distributorFee, controller);
    splitData.push(data);
    return address(0xFFFF);
  }

  function showSplitRecipient(uint256 index) external view returns (address) {
    return splitData[0].recipients[index];
  }

  function showSplitAllocation(uint256 index) external view returns (uint32) {
    return splitData[0].percentAllocations[index];
  }

  function showController() external view returns (address) {
    return splitData[0].controller;
  }
}
