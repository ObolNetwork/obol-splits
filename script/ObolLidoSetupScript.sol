// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {ISplitMain, SplitConfiguration} from "src/interfaces/ISplitMain.sol";
import {ObolLidoSplitFactory} from "src/lido/ObolLidoSplitFactory.sol";
import {SplitterConfiguration} from "./SplitterConfiguration.sol";

/// @title ObolLidoScript
/// @author Obol
/// @notice Creates Split and ObolLidoSplit Addresses
///
/// @dev Takes a json file following the format defined at ./data/lido-data-sample.json
/// and deploys split and ObolLido split contracts.
///
/// It outputs the result of the script to "./result.json"
///
/// NOTE: It's COMPULSORY the json file supplied follows the arrangement format defined
/// in the sample file else the json parse will fail.
///
///
/// To Run
///
/// Step 1 fill in the appropriate details for env vars
/// > cp .env.deployment .env
///
/// Step 2 add to environment
/// > source .env
///
/// Step 3 Run forge script to simulate the execution of the transaction
///
/// > forge script script/ObolLidoSetupScript.sol:ObolLidoSetupScript --fork-url $RPC_URL -vvvv --sig
/// "run(string,address,address)" "<PATH_TO_JSON_FILE e.g. ./script/data/lido-data-sample.json>" $SPLITMAIN
/// $OBOL_LIDO_SPLIT_FACTORY
///
/// add --broadcast flag to broadcast to the public blockchain

contract ObolLidoSetupScript is Script, SplitterConfiguration {
  function run(string memory jsonFilePath, address splitMain, address obolLidoSplitFactory) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");

    string memory file = vm.readFile(jsonFilePath);
    bytes memory parsedJson = vm.parseJson(file);
    JsonSplitData[] memory configuration = abi.decode(parsedJson, (JsonSplitData[]));
    _validateSplitInputJson(configuration);

    // deploy the split and obol script
    string memory jsonKey = "lidoObolDeploy";
    string memory finalJSON;

    for (uint256 j = 0; j < configuration.length; j++) {
      string memory objKey = vm.toString(j);
      // deploy split
      JsonSplitData memory currentConfiguration = configuration[j];

      vm.startBroadcast(privKey);

      address split = ISplitMain(splitMain).createSplit(
        currentConfiguration.accounts,
        currentConfiguration.percentAllocations,
        currentConfiguration.distributorFee,
        currentConfiguration.controller
      );

      // create obol split
      address obolLidoSplitAdress = ObolLidoSplitFactory(obolLidoSplitFactory).createCollector(address(0), split);

      vm.stopBroadcast();

      vm.serializeAddress(objKey, "splitAddress", split);
      string memory response = vm.serializeAddress(objKey, "obolLidoSplitAddress", obolLidoSplitAdress);

      finalJSON = vm.serializeString(jsonKey, objKey, response);
    }

    vm.writeJson(finalJSON, "./result.json");
  }
}
