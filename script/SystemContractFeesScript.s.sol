// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";

contract SystemContractFees is Script {
  // From https://github.com/ethereum/EIPs/blob/d96625a4dcbbe2572fa006f062bd02b4582eefd5/EIPS/eip-7251.md#execution-layer
  address constant consolidationSysContract = 0x00431F263cE400f4455c2dCf564e53007Ca4bbBb;
  // From https://github.com/ethereum/EIPs/blob/d96625a4dcbbe2572fa006f062bd02b4582eefd5/EIPS/eip-7002.md#configuration
  address constant withdrawalSysContract = 0x0c15F14308530b7CDB8460094BbB9cC28b9AaaAA;

  function run() view external {
    (bool ok1, bytes memory consolidationFeeData) = consolidationSysContract.staticcall('');
    require(ok1, 'Failed to get consolidation fee');

    (bool ok2, bytes memory withdrawalFeeData) = withdrawalSysContract.staticcall('');
    require(ok2, 'Failed to get withdrawal fee');

    console.log('Consolidation Fee: ', uint256(bytes32(consolidationFeeData)));
    console.log('Withdrawal Fee: ', uint256(bytes32(withdrawalFeeData)));
  }
}
