// SPDX-License-Identifier: NONE
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";

library Utils {
  // This function prints the explorer URL for a given address based on the current chain ID.
  function printExplorerUrl(address addr) internal view {
    string memory baseUrl;
    if (block.chainid == 1) baseUrl = "https://etherscan.io/address/";
    else if (block.chainid == 11_155_111) baseUrl = "https://sepolia.etherscan.io/address/";
    else if (block.chainid == 560_048) baseUrl = "https://hoodi.etherscan.io/address/";
    else baseUrl = "https://etherscan.io/address/"; // Default fallback

    console.log("Explorer URL for address %s%s", baseUrl, addr);
  }

  // This function checks if an address is a contract by checking its code length.
  function isContract(address addr) internal view returns (bool) {
    uint256 codeLength;
    assembly {
      codeLength := extcodesize(addr)
    }
    return codeLength > 0;
  }
}
