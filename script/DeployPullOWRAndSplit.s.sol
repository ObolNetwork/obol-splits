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
    /// @param splitMain address for 0xsplits splitMain
    /// @param pullOwrFactory address for factory
    function run(string memory jsonFilePath, address splitMain, address pullOwrFactory, uint256 stakeSize)
        external
    {
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        bytes memory parsedJson = vm.parseJson(vm.readFile(jsonFilePath));

        ConfigurationData[] memory data = abi.decode(parsedJson, (ConfigurationData[]));
        _validateInputJson(data);

        // deploy the split and obol script
        string memory jsonKey = "pullOwrDeploy";
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
            address pullOwrAddress = address(
                OptimisticPullWithdrawalRecipientFactory(pullOwrFactory).createOWRecipient(
                    ETH_ADDRESS, currentConfiguration.recoveryRecipient, currentConfiguration.principalRecipient, split, stakeAmount
                )
            );

            vm.stopBroadcast();

            string memory objKey = vm.toString(i);

            vm.serializeAddress(objKey, "splitAddress", split);
            string memory repsonse = vm.serializeAddress(objKey, "pullOWRAddress", pullOwrAddress);

            finalJSON = vm.serializeString(jsonKey, objKey, repsonse);
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