// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/console.sol";

contract WithdrawalSystemContractMock {
  bytes[] public withdrawalRequests;

  receive() external payable {}

  fallback(bytes calldata) external payable returns (bytes memory) {
    // If calldata is empty, return the fee
    if (msg.data.length == 0) {
      uint256 feeWei = 1 << withdrawalRequests.length;
      return abi.encodePacked(bytes32(uint256(feeWei)));
    }

    // If calldata is not empty, consider it a withdrawal request
    // Expected data: 48+8 bytes
    if (msg.data.length != 56) {
      revert("Invalid calldata length");
    }

    withdrawalRequests.push(msg.data);

    return abi.encodePacked(true);
  }
}
