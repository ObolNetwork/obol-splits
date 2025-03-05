// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {LibString} from "solady/utils/LibString.sol";
import {BaseScript} from "./BaseScript.s.sol";
import {ISplitWalletV2} from "../../src/interfaces/ISplitWalletV2.sol";
import {stdJson} from "forge-std/StdJson.sol";

//
// This script reads Split balances previously deployed with DeployScript.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
// Example usage:
//   forge script script/splits/GetBalancesScript.s.sol --sig "run(string)" -vvv \
//     --rpc-url https://your-rpc-provider "<splits_deployment_file_path>"
//
contract GetBalancesScript is BaseScript {
  using stdJson for string;

  function run(string memory splitsDeploymentFilePath) external view {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    if (privKey == 0) {
      console.log("PRIVATE_KEY is not set");
      return;
    }

    console.log("Reading splits deployment from file: %s", splitsDeploymentFilePath);
    string memory deploymentsFile = vm.readFile(splitsDeploymentFilePath);

    string[] memory keys = vm.parseJsonKeys(deploymentsFile, ".");
    for (uint256 i = 0; i < keys.length; i++) {
      string memory key = string.concat(".", keys[i]);
      address splitAddress = vm.parseJsonAddress(deploymentsFile, key);
      ISplitWalletV2 splitWallet = ISplitWalletV2(splitAddress);
      address nativeToken = splitWallet.NATIVE_TOKEN();
      (uint256 splitBalance, uint256 warehouseBalance) = splitWallet.getSplitBalance(nativeToken);
      console.log("Split %s at %s:", keys[i], splitAddress);
      console.log("  split balance: %d gwei", splitBalance / 1e9);
      console.log("  warehouse balance: %d gwei", warehouseBalance / 1e9);
    }
  }
}

