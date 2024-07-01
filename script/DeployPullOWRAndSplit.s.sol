// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {OptimisticPullWithdrawalRecipientFactory} from "src/owr/OptimisticPullWithdrawalRecipientFactory.sol";
import {ISplitMain, SplitConfiguration} from "src/interfaces/external/splits/ISplitMain.sol";
import {SplitterConfiguration} from "./SplitterConfiguration.sol";

contract DeployPullOWRAndSplit is Script, SplitterConfiguration {
    address private constant ETH_ADDRESS = address(0);

    error Invalid_PrincipalRecipient();

    struct ConfigurationData {
        address principalRecipient;
        address recoveryRecipient;
        JsonSplitData split;
    }

    /// @param jsonFilePath the data format can be seen in ./data/deploy-pullOWR-sample.json
    /// @param split address for 0xsplits PullSplit
    /// @param pullOwrFactory address for factory
    function run(string memory jsonFilePath, address split, address pullOwrFactory, uint256 stakeSize)
        external
    {   
        // string memory jsonFilePath = "script/data/deploy-pullOwr-sample.json";
        // address pullOwrFactory = 0xcFf568fBD1386f0d7784C174411341C8588d4Ba4;
        // address split = 0x2636b017110c4d8977C6a7351D1de09e95fd595a;
        // uint256 stakeSize = 32;

        uint256 privKey = vm.envUint("PRIVATE_KEY");
        bytes memory parsedJson = vm.parseJson(vm.readFile(jsonFilePath));
        
        ConfigurationData[] memory data = abi.decode(parsedJson, (ConfigurationData[]));
        _validateInputJson(data);

        // deploy the split and obol script
        string memory jsonKey = "pullOwrDeploy";
        string memory finalJSON;

        for (uint256 i = 0; i < data.length; i++) {
            {
                vm.startBroadcast(privKey);

                ConfigurationData memory currentConfiguration = data[i];
                address pullOwrAddress = address(
                    OptimisticPullWithdrawalRecipientFactory(pullOwrFactory).createOWRecipient(
                        ETH_ADDRESS, currentConfiguration.recoveryRecipient, currentConfiguration.principalRecipient, split, stakeSize * 1 ether
                    )
                );

                vm.stopBroadcast();

                 string memory objKey = vm.toString(i);

                vm.serializeAddress(objKey, "splitAddress", split);
                string memory repsonse = vm.serializeAddress(objKey, "pullOWRAddress", pullOwrAddress);

                finalJSON = vm.serializeString(jsonKey, objKey, repsonse);
            }
           
        }

        vm.writeJson(finalJSON, "./pullOwr-split.json");
    }

    function _validateInputJson(ConfigurationData[] memory configuration) internal pure {
        for (uint256 i = 0; i < configuration.length; i++) {
        if (configuration[i].principalRecipient == address(0)) revert Invalid_PrincipalRecipient();
            _validateSplitInputJson(configuration[i].split);
        }
    }
}