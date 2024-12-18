// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/console.sol";

contract ExecutionLayerWithdrawalSystemContractMock {
  uint64 public receivedAmount;

  receive() external payable {}

  fallback(bytes calldata) external payable returns (bytes memory) {
    // Input data has the following layout:
    //
    //  +--------+--------+
    //  | pubkey | amount |
    //  +--------+--------+
    //      48       8
    bytes memory data = msg.data;

    bytes memory pubkey = new bytes(48);
    assembly {
      pubkey := mload(add(data, 48))
    }

    uint64 amount;
    assembly {
      let word := mload(add(data, 56))

      // Extract the last 8 bytes (uint64)
      amount := and(shr(192, word), 0xFFFFFFFFFFFFFFFF)
    }

    receivedAmount = amount;

    return abi.encodePacked(bytes32(uint256(0.1 ether)));
  }
}
