// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {OptimisticTokenWithdrawalRecipientFactory} from "src/owr/token/OptimisticTokenWithdrawalRecipientFactory.sol";
import {ISplitMain, SplitConfiguration} from "src/interfaces/ISplitMain.sol";
import {SplitterConfiguration} from "./SplitterConfiguration.sol";

contract DeployOTWRAndSplit is Script, SplitterConfiguration {
  error Invalid_PrincipalRecipient();

  struct ConfigurationData {
    address principalRecipient;
    JsonSplitData split;
  }

  /// @param jsonFilePath the data format can be seen in ./data/deploy-otwr-sample.json
  /// @param token address of the OTWR token
  /// @param splitMain address for 0xsplits splitMain
  /// @param OTWRFactory address for factory
  /// @param stakeSize in normal numbers e.g. 32 for 32 ether
  function run(string memory jsonFilePath, address token, address splitMain, address OTWRFactory, uint256 stakeSize)
    external
  {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    bytes memory parsedJson = vm.parseJson(vm.readFile(jsonFilePath));

    ConfigurationData[] memory data = abi.decode(parsedJson, (ConfigurationData[]));
    _validateInputJson(data);

    // deploy the split and obol script
    string memory jsonKey = "otwrDeploy";
    string memory finalJSON;

    uint256 stakeAmount = stakeSize * 1 ether;

    for (uint256 i = 0; i < data.length; i++) {
      // deploy split
      ConfigurationData memory currentConfiguration = data[i];

      vm.startBroadcast(privKey);

      address split = ISplitMain(splitMain).createSplit(
        currentConfiguration.split.accounts,
        currentConfiguration.split.percentAllocations,
        currentConfiguration.split.distributorFee,
        currentConfiguration.split.controller
      );

      // create obol split
      address otwrAddress = address(
        OptimisticTokenWithdrawalRecipientFactory(OTWRFactory).createOWRecipient(
          token, address(0), currentConfiguration.principalRecipient, split, stakeAmount
        )
      );

      vm.stopBroadcast();

      string memory objKey = vm.toString(i);

      vm.serializeAddress(objKey, "splitAddress", split);
      string memory response = vm.serializeAddress(objKey, "OTWRAddress", otwrAddress);

      finalJSON = vm.serializeString(jsonKey, objKey, response);
    }

    vm.writeJson(finalJSON, "./otwr-split.json");
  }

  function _validateInputJson(ConfigurationData[] memory configuration) internal pure {
    for (uint256 i = 0; i < configuration.length; i++) {
      if (configuration[i].principalRecipient == address(0)) revert Invalid_PrincipalRecipient();
      _validateSplitInputJson(configuration[i].split);
    }
  }
}
