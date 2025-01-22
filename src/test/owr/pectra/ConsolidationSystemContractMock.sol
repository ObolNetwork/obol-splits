// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/console.sol";

contract ConsolidationSystemContractMock {
  bytes[] public consolidationRequests;

  receive() external payable {}

  fallback(bytes calldata) external payable returns (bytes memory) {
    // If calldata is empty, return the fee
    if (msg.data.length == 0) {
      uint256 feeWei = 1 << consolidationRequests.length;
      return abi.encodePacked(bytes32(uint256(feeWei)));
    }

    // If calldata is not empty, consider it a consolidation request
    // Expected data: 48+48 bytes
    if (msg.data.length != 96) {
      revert("Invalid calldata length");
    }

    consolidationRequests.push(msg.data);

    return abi.encodePacked(true);
  }
}
