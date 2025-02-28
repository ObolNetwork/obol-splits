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

  mapping(string => address) private deployments;

  struct SplitConfig {
    // fields must be sorted alphabetically
    SplitAllocation[] allocations;
    uint256 distributionIncentive;
    string name;
    address owner;
    string splitType;
    uint256 totalAllocation;
  }

  struct SplitAllocation {
    // fields must be sorted alphabetically
    uint256 allocation;
    address recipient;
  }

  function run(address pullSplitFactory, address pushSplitFactory, string memory splitsConfigFilePath) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    if (privKey == 0) {
      console.log("PRIVATE_KEY is not set");
      return;
    }

    address deployerAddress = vm.addr(privKey);
    console.log("Deployer address: %s", deployerAddress);

    string memory splitsConfigFileName = getFileName(splitsConfigFilePath);
    console.log("Reading splits configuration from file: %s", splitsConfigFileName);

    string memory file = vm.readFile(splitsConfigFilePath);
    bytes memory parsedJson = vm.parseJson(file);

    SplitConfig[] memory splits = abi.decode(parsedJson, (SplitConfig[]));

    console.log("Found %d split configurations", splits.length);

    vm.startBroadcast(privKey);

    // Deploying splits
    for (uint256 i = 0; i < splits.length; i++) {
      SplitConfig memory split = splits[i];
      console.log("Deploying split %s", split.name);
      console.log("  Split type: %s", split.splitType);
      console.log("  Total allocation: %d", split.totalAllocation);
      console.log("  Distribution incentive: %d", split.distributionIncentive);
      console.log("  Owner: %s", split.owner);

      address[] memory recipients = new address[](split.allocations.length);
      uint256[] memory allocations = new uint256[](split.allocations.length);

      for (uint256 j = 0; j < split.allocations.length; j++) {
        recipients[j] = split.allocations[j].recipient;
        allocations[j] = split.allocations[j].allocation;

        console.log("  Recipient %d: %s, allocation: %d", j, recipients[j], allocations[j]);
      }

      ISplitFactoryV2.Split memory newSplit = ISplitFactoryV2.Split({
        recipients: recipients,
        allocations: allocations,
        totalAllocation: split.totalAllocation,
        distributionIncentive: uint16(split.distributionIncentive)
      });

      address splitAddress;
      if (compareStrings(split.splitType, "pull")) {
        ISplitFactoryV2 pullFactory = ISplitFactoryV2(pullSplitFactory);
        splitAddress = pullFactory.createSplit(newSplit, split.owner, deployerAddress);
      } else if (compareStrings(split.splitType, "push")) {
        ISplitFactoryV2 pushFactory = ISplitFactoryV2(pushSplitFactory);
        splitAddress = pushFactory.createSplit(newSplit, split.owner, deployerAddress);
      } else {
        console.log("Unknown split type: %s", split.splitType);
        revert("Unsupported split type provided.");
      }

      console.log("  Split %s deployed at", split.name, splitAddress);
      deployments[split.name] = splitAddress;
    }

    writeDeploymentJson(splitsConfigFileName, splits);

    vm.stopBroadcast();
  }

  function compareStrings(string memory a, string memory b) public pure returns (bool) {
    return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
  }

  function getFileName(string memory filePath) public pure returns (string memory) {
    bytes memory pathBytes = bytes(filePath);
    uint256 lastSlashIndex = 0;
    for (uint256 i = 0; i < pathBytes.length; i++) {
      if (pathBytes[i] == "/") {
        lastSlashIndex = i;
      }
    }
    bytes memory fileNameBytes = new bytes(pathBytes.length - lastSlashIndex - 1);
    for (uint256 i = 0; i < fileNameBytes.length; i++) {
      fileNameBytes[i] = pathBytes[lastSlashIndex + 1 + i];
    }
    return string(fileNameBytes);
  }

  function fileExists(string memory filePath) internal view returns (bool) {
    try vm.readFile(filePath) {
      return true;
    } catch {
      return false;
    }
  }

  function writeDeploymentJson(string memory splitsConfigFileName, SplitConfig[] memory splits) internal {
    string memory deploymentsDir = string.concat(vm.projectRoot(), "/deployments");
    if (!fileExists(deploymentsDir)) {
      vm.createDir(deploymentsDir, true);
    }

    string memory file = string.concat(vm.projectRoot(), "/deployments/", splitsConfigFileName);
    string memory json;
    for (uint256 i = 0; i < splits.length; i++) {
      SplitConfig memory split = splits[i];
      json = json.serialize(split.name, deployments[split.name]);
    }
    vm.writeFile(file, json);
  }
}

// forge script script/DeploySplitsScript.s.sol --sig "run(address,string)" -vvv --rpc-url https://eth-holesky.g.alchemy.com/v2/i473a8Ir6JiM046ZLMMH7lxyNbuULJye --broadcast "0x5cbA88D55Cec83caD5A105Ad40C8c9aF20bE21d1" "0xDc6259E13ec0621e6F19026b2e49D846525548Ed" "./script/data/single-split-config-sample.json"

/* HOLESKY
{
    "PullSplitFactory": "0x80f1B766817D04870f115fEBbcCADF8DBF75E017",
    "PullSplitFactoryV2": "0x5cbA88D55Cec83caD5A105Ad40C8c9aF20bE21d1",
    "PushSplitFactory": "0xaDC87646f736d6A82e9a6539cddC488b2aA07f38",
    "PushSplitFactoryV2": "0xDc6259E13ec0621e6F19026b2e49D846525548Ed",
    "SplitsWarehouse": "0x8fb66F38cF86A3d5e8768f8F1754A24A6c661Fb8"
}
*/
