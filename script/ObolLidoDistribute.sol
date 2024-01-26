// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {ISplitMain, ERC20} from "src/interfaces/ISplitMain.sol";
import { ObolLidoSplit } from "src/lido/ObolLidoSplit.sol";

contract ObolLidoDistribute is Script {

    struct DistributeSplitConfiguration {
        address[] accounts;
        address controller;
        uint32 distributorFee;
        address obolLidoSplitAddress;
        uint32[] percentAllocations;
        address splitAddress;
    }

    function run(
        string memory jsonFilePath,
        address splitMain
    ) external {
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        address WSTETH_HOLESKY = vm.envAddress("WSTETH_ADDRESS");
        address STETH_HOLESKY = vm.envAddress("STETH_ADDRESS");

        string memory file = vm.readFile(jsonFilePath);
        bytes memory parsedJson = vm.parseJson(file);
        
        DistributeSplitConfiguration[] memory data = abi.decode(parsedJson, (DistributeSplitConfiguration[]));

        for (uint256 j = 0; j < data.length; j++) {
            DistributeSplitConfiguration memory configItem = data[j];
            
            if (ERC20(STETH_HOLESKY).balanceOf(configItem.obolLidoSplitAddress) > 0) {
                vm.startBroadcast(privKey);

                if (configItem.obolLidoSplitAddress != address(0)) {
                    // call distribute on obol lido split
                    ObolLidoSplit(configItem.obolLidoSplitAddress).distribute();
                }

                // call distribute on splitMain
                ISplitMain(splitMain).distributeERC20(
                    configItem.splitAddress,
                    ERC20(WSTETH_HOLESKY),
                    configItem.accounts,
                    configItem.percentAllocations,
                    configItem.distributorFee,
                    address(0)
                );
                
                vm.stopBroadcast();

            }


        }
    }
}