// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {LibString} from "solady/utils/LibString.sol";

// The base script contains shared functionality for Splits.
contract BaseScript is Script {
  using stdJson for string;

  // Maximum number of splits in the configuration file
  uint256 internal constant MAX_SPLITS = 32;

  // Maximum number of split allocations in the configuration file
  uint256 internal constant MAX_ALLOCATIONS = 32;

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

  // Reads the splits configuration from a JSON file.
  function readSplitsConfig(string memory splitsConfigFilePath) public view returns (SplitConfig[] memory) {
    string memory file = vm.readFile(splitsConfigFilePath);

    uint256 totalSplits = countJsonArray(file, "", MAX_SPLITS);
    require(totalSplits > 0, "No splits found in the configuration file.");

    SplitConfig[] memory splits = new SplitConfig[](totalSplits);

    for (uint256 i = 0; i < totalSplits; i++) {
      string memory key = string.concat(".[", vm.toString(i), "]");

      SplitConfig memory split;
      split.name = file.readString(string.concat(key, ".name"));
      split.owner = file.readAddress(string.concat(key, ".owner"));
      split.splitType = file.readString(string.concat(key, ".splitType"));
      split.totalAllocation = file.readUint(string.concat(key, ".totalAllocation"));
      split.distributionIncentive = file.readUint(string.concat(key, ".distributionIncentive"));

      uint256 totalAllocations = countJsonArray(file, string.concat(key, ".allocations"), MAX_ALLOCATIONS);
      require(totalAllocations > 0, "No allocations found for the current split.");
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

  // Counts the number of elements in a JSON array.
  function countJsonArray(string memory json, string memory keyPrefix, uint256 max) public view returns (uint256) {
    for (uint256 i = 0; i < max; i++) {
      string memory key = string.concat(keyPrefix, ".[", vm.toString(i), "]");
      if (!json.keyExists(key)) {
        return i;
      }
    }
    
    revert("Exceeded maximum number of elements in JSON array");
  }
}
