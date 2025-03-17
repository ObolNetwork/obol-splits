// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ISplitFactoryV2} from "../../src/interfaces/ISplitFactoryV2.sol";
import {LibString} from "solady/utils/LibString.sol";
import {BaseScript} from "./BaseScript.s.sol";

//
// This script deploys Split contracts using provided SplitFactories,
// in accordance with the splits configuration file.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
// Example usage:
//   forge script script/splits/DeployScript.s.sol --sig "run(address,address,string)" \
//     --rpc-url https://your-rpc-provider --broadcast -vvv \
//      "<pull_split_factory>" "<push_split_factory>" "<splits_config_file_path>"
//
// SplitFactory addresses can be found here:
// https://github.com/0xSplits/splits-contracts-monorepo/tree/main/packages/splits-v2/deployments
//
contract DeployScript is BaseScript {
  using stdJson for string;

  // To detect loops in splits configuration
  address private constant DEPLOYING_SPLIT = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;

  mapping(string => address) private deployments;
  mapping(string => uint256) private indices;

  address private deployerAddress;
  ISplitFactoryV2 private pullFactory;
  ISplitFactoryV2 private pushFactory;

  function run(address pullSplitFactory, address pushSplitFactory, string memory splitsConfigFilePath) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    if (privKey == 0) {
      console.log("PRIVATE_KEY is not set");
      return;
    }
    deployerAddress = vm.addr(privKey);

    require(pullSplitFactory != address(0), "PullSplitFactory address is not set");
    require(pushSplitFactory != address(0), "PushSplitFactory address is not set");
    pullFactory = ISplitFactoryV2(pullSplitFactory);
    pushFactory = ISplitFactoryV2(pushSplitFactory);

    console.log("Reading splits configuration from file: %s", splitsConfigFilePath);
    SplitConfig[] memory configSplits = readSplitsConfig(splitsConfigFilePath);
    require(configSplits.length > 0, "No splits found in the configuration file.");
    console.log("Found %d splits in the configuration file", configSplits.length);

    for (uint256 i = 0; i < configSplits.length; i++) {
      indices[configSplits[i].name] = i;
    }

    vm.startBroadcast(privKey);

    for (uint256 i = 0; i < configSplits.length; i++) {
      deploySplit(configSplits, configSplits[i].name);
    }

    writeDeploymentJson(getFileName(splitsConfigFilePath), configSplits);

    vm.stopBroadcast();
  }

  function deploySplit(SplitConfig[] memory configSplits, string memory splitName) public returns (address) {
    if (deployments[splitName] != address(0) && deployments[splitName] != DEPLOYING_SPLIT) {
      return deployments[splitName];
    }

    if (deployments[splitName] == DEPLOYING_SPLIT) {
      console.log("Split %s is already processing, it must be a loop", splitName);
      revert("Loop detected in splits configuration.");
    }
    deployments[splitName] = DEPLOYING_SPLIT;

    SplitConfig memory split = configSplits[indices[splitName]];

    address[] memory recipients = new address[](split.allocations.length);
    uint256[] memory allocations = new uint256[](split.allocations.length);

    for (uint256 j = 0; j < split.allocations.length; j++) {
      if (LibString.startsWith(split.allocations[j].recipient, "0x")) {
        recipients[j] = vm.parseAddress(split.allocations[j].recipient);
      } else if (bytes(split.allocations[j].recipient).length > 0) {
        recipients[j] = deploySplit(configSplits, split.allocations[j].recipient);
      } else {
        console.log("Recipient address is not set for allocation %d in split %s", j, splitName);
        revert("Recipient address is not set for allocation.");
      }

      allocations[j] = split.allocations[j].allocation;
    }

    ISplitFactoryV2.Split memory newSplit = ISplitFactoryV2.Split({
      recipients: recipients,
      allocations: allocations,
      totalAllocation: split.totalAllocation,
      distributionIncentive: uint16(split.distributionIncentive)
    });

    address splitAddress;
    if (compareStrings(split.splitType, "pull")) {
      splitAddress = pullFactory.createSplit(newSplit, split.owner, deployerAddress);
    } else if (compareStrings(split.splitType, "push")) {
      splitAddress = pushFactory.createSplit(newSplit, split.owner, deployerAddress);
    } else {
      console.log("Unknown split type: %s", split.splitType);
      revert("Unsupported split type provided. Allowed pull or push only.");
    }

    console.log("Split %s deployed at", split.name, splitAddress);
    deployments[split.name] = splitAddress;

    return splitAddress;
  }

  function compareStrings(string memory a, string memory b) public pure returns (bool) {
    return LibString.eq(a, b);
  }

  function getFileName(string memory filePath) public pure returns (string memory) {
    return LibString.slice(filePath, LibString.lastIndexOf(filePath, "/") + 1, bytes(filePath).length);
  }

  function writeDeploymentJson(string memory _splitsConfigFileName, SplitConfig[] memory _splits) internal {
    string memory deploymentsDir = string.concat(vm.projectRoot(), "/deployments");
    if (!vm.exists(deploymentsDir)) {
      vm.createDir(deploymentsDir, true);
    }

    string memory file = string.concat(vm.projectRoot(), "/deployments/", _splitsConfigFileName);
    string memory root;
    string memory last;
    for (uint256 i = 0; i < _splits.length; i++) {
      SplitConfig memory split = _splits[i];
      last = root.serialize(split.name, deployments[split.name]);
    }
    vm.writeFile(file, last);

    console.log("Deployments saved to file: %s", file);
  }
}
