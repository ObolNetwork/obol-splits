// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {LibString} from "solady/utils/LibString.sol";
import {BaseScript} from "./BaseScript.s.sol";
import {ISplitWalletV2} from "../../src/interfaces/ISplitWalletV2.sol";
import {ISplitFactoryV2} from "../../src/interfaces/ISplitFactoryV2.sol";
import {stdJson} from "forge-std/StdJson.sol";

//
// This script calls distribute() for deployed Splits.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will distribute the rewards in the splitter. 
// Example usage:
//   forge script script/splits/DistributeScript.s.sol --sig "run(string,string)" -vvv --broadcast \
//     --rpc-url https://your-rpc-provider "<splits_deployment_file_path>" "<splits_config_file_path>"
//
contract DistributeScript is BaseScript {
  using stdJson for string;

  mapping(string => uint256) private indices;
  address private distributorAddress;

  function run(string memory splitsDeploymentFilePath, string memory splitsConfigFilePath) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    if (privKey == 0) {
      console.log("PRIVATE_KEY is not set");
      return;
    }

    SplitConfig[] memory splits = readSplitsConfig(splitsConfigFilePath);
    for (uint256 i = 0; i < splits.length; i++) {
      indices[splits[i].name] = i;
    }
    distributorAddress = vm.addr(privKey);

    console.log("Reading splits deployment from file: %s", splitsDeploymentFilePath);
    string memory deploymentsFile = vm.readFile(splitsDeploymentFilePath);

    vm.startBroadcast(privKey);

    string[] memory keys = vm.parseJsonKeys(deploymentsFile, ".");
    for (uint256 i = 0; i < keys.length; i++) {
      uint256 splitIndex = indices[keys[i]];
      SplitConfig memory splitConfig = splits[splitIndex];

      string memory key = string.concat(".", keys[i]);
      address splitAddress = vm.parseJsonAddress(deploymentsFile, key);
      ISplitWalletV2 splitWallet = ISplitWalletV2(splitAddress);
      address nativeToken = splitWallet.NATIVE_TOKEN();
      console.log("Calling distribute() for split %s at %s:", keys[i], splitAddress);

      address[] memory recipients = new address[](splitConfig.allocations.length);
      uint256[] memory allocations = new uint256[](splitConfig.allocations.length);
      
      for (uint256 j = 0; j < splitConfig.allocations.length; j++) {
        allocations[j] = splitConfig.allocations[j].allocation;

        if (LibString.startsWith(splitConfig.allocations[j].recipient, "0x")) {
          recipients[j] = vm.parseAddress(splitConfig.allocations[j].recipient);
        } else if (bytes(splitConfig.allocations[j].recipient).length > 0) {
          string memory jsonKey = string.concat(".", splitConfig.allocations[j].recipient);
          recipients[j] = vm.parseJsonAddress(deploymentsFile, jsonKey);
        }
      }

      sortRecipientsAndAllocations(recipients, allocations, 0, int(recipients.length - 1));

      splitWallet.distribute(
        ISplitFactoryV2.Split({
          recipients: recipients,
          allocations: allocations,
          totalAllocation: splitConfig.totalAllocation,
          distributionIncentive: uint16(splitConfig.distributionIncentive)
        }),
        nativeToken,
        distributorAddress
      );
    }

    vm.stopBroadcast();
  }
}
