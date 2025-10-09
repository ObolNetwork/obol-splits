// SPDX-License-Identifier: Proprietary
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// The script simply prints the immediate fees for the system contracts.
contract SystemContractFeesScript is Script {
  // From https://github.com/ethereum/EIPs/blob/master/EIPS/eip-7251.md
  address constant consolidationSysContract = 0x0000BBdDc7CE488642fb579F8B00f3a590007251;
  // From https://github.com/ethereum/EIPs/blob/master/EIPS/eip-7002.md
  address constant withdrawalSysContract = 0x00000961Ef480Eb55e80D19ad83579A64c007002;

  function run() external view {
    (bool ok1, bytes memory consolidationFeeData) = consolidationSysContract.staticcall("");
    require(ok1, "Failed to get consolidation fee");

    (bool ok2, bytes memory withdrawalFeeData) = withdrawalSysContract.staticcall("");
    require(ok2, "Failed to get withdrawal fee");

    console.log("Consolidation Fee", uint256(bytes32(consolidationFeeData)), "WEI");
    console.log("Withdrawal Fee", uint256(bytes32(withdrawalFeeData)), "WEI");
  }
}
