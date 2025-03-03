// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ISplitFactoryV2} from "../src/interfaces/ISplitFactoryV2.sol";
import {LibString} from "solady/utils/LibString.sol";

//
// This script deploys Split contracts using provided SplitFactory,
// in according with the splits configuration file.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
// Example usage:
//   forge script script/DeploySplitsScript.s.sol --sig "run(address,address,string)" -vvv \
//     --rpc-url https://rpc.pectra-devnet-6.ethpandaops.io/ --broadcast \
//      "<pull_split_factory>" "<push_split_factory>" "<splits_config_file_path>"
//
// SplitFactory addresses can be found here:
// https://github.com/0xSplits/splits-contracts-monorepo/tree/main/packages/splits-v2/deployments
//
contract DeploySplitsScript is Script {
  using stdJson for string;

  // To detect loops in splits configuration
  uint256 private constant MAX_ARRAY_ENTRIES = 100;
  address private constant DEPLOYING_SPLIT = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;

  mapping(string => address) private deployments;
  mapping(string => uint256) private indices;

  address private deployerAddress;
  ISplitFactoryV2 private pullFactory;
  ISplitFactoryV2 private pushFactory;

  struct SplitConfig {
    SplitAllocation[] allocations;
    uint256 distributionIncentive;
    string name;
    address owner;
    string splitType;
    uint256 totalAllocation;
  }

  struct SplitAllocation {
    uint256 allocation;
    string recipient;
  }

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

    // Recursively deploying splits
    deploySplit(configSplits, configSplits[0].name);

    writeDeploymentJson(getFileName(splitsConfigFilePath), configSplits);

    vm.stopBroadcast();
  }

  function deploySplit(SplitConfig[] memory configSplits, string memory splitName) public returns (address) {
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

  function readSplitsConfig(string memory splitsConfigFilePath) public view returns (SplitConfig[] memory) {
    string memory file = vm.readFile(splitsConfigFilePath);

    uint256 totalSplits = countJsonArray(file, "");
    SplitConfig[] memory splits = new SplitConfig[](totalSplits);

    for (uint256 i = 0; i < totalSplits; i++) {
      string memory key = string.concat(".[", vm.toString(i), "]");

      SplitConfig memory split;
      split.name = file.readString(string.concat(key, ".name"));
      split.owner = file.readAddress(string.concat(key, ".owner"));
      split.splitType = file.readString(string.concat(key, ".splitType"));
      split.totalAllocation = file.readUint(string.concat(key, ".totalAllocation"));
      split.distributionIncentive = file.readUint(string.concat(key, ".distributionIncentive"));

      uint256 totalAllocations = countJsonArray(file, string.concat(key, ".allocations"));
      split.allocations = new SplitAllocation[](totalAllocations);

      for (uint256 j = 0; j < totalAllocations; j++) {
        string memory allocationKey = string.concat(key, ".allocations.[", vm.toString(j), "]");
        if (!file.keyExists(allocationKey)) {
          break;
        }

        SplitAllocation memory splitAllocation;
        splitAllocation.recipient = file.readString(string.concat(allocationKey, ".recipient"));
        splitAllocation.allocation = file.readUint(string.concat(allocationKey, ".allocation"));
        split.allocations[j] = splitAllocation;
      }

      splits[i] = split;
    }

    return splits;
  }

  function countJsonArray(string memory json, string memory keyPrefix) public view returns (uint256) {
    for (uint256 i = 0; i < MAX_ARRAY_ENTRIES; i++) {
      string memory key = string.concat(keyPrefix, ".[", vm.toString(i), "]");
      if (!json.keyExists(key)) {
        return i;
      }
    }
    return 0;
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

// forge script script/DeploySplitsScript.s.sol --sig "run(address,address,string)" --rpc-url https://eth-holesky.g.alchemy.com/v2/i473a8Ir6JiM046ZLMMH7lxyNbuULJye "0x5cbA88D55Cec83caD5A105Ad40C8c9aF20bE21d1" "0xDc6259E13ec0621e6F19026b2e49D846525548Ed" "./script/data/nested-split-config-sample.json" --broadcast -vvv

/* HOLESKY
{
    "PullSplitFactory": "0x80f1B766817D04870f115fEBbcCADF8DBF75E017",
    "PullSplitFactoryV2": "0x5cbA88D55Cec83caD5A105Ad40C8c9aF20bE21d1",
    "PushSplitFactory": "0xaDC87646f736d6A82e9a6539cddC488b2aA07f38",
    "PushSplitFactoryV2": "0xDc6259E13ec0621e6F19026b2e49D846525548Ed",
    "SplitsWarehouse": "0x8fb66F38cF86A3d5e8768f8F1754A24A6c661Fb8"
}
*/
