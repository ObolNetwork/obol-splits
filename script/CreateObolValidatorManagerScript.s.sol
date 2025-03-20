// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ObolValidatorManagerFactory} from "../src/ovm/ObolValidatorManagerFactory.sol";
import {ObolValidatorManager} from "../src/ovm/ObolValidatorManager.sol";

//
// This script creates a new ObolValidatorManager contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
// Example usage:
//   forge script script/CreateObolValidatorManagerScript.s.sol --sig "run(address)" \
//   --rpc-url https://rpc.pectra-devnet-5.ethpandaops.io/ --broadcast "<factory_address>"
//
contract CreateObolValidatorManagerScript is Script {
    function run(address deployedFactory) external {
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(privKey);

        console.log("Deployer address: ", deployerAddress);

        vm.startBroadcast(privKey);

        ObolValidatorManagerFactory factory = ObolValidatorManagerFactory(deployedFactory);

        address owner = deployerAddress;
        address principalRecipient = deployerAddress;
        address rewardsRecipient = deployerAddress;
        uint64 principalThreshold = 16 ether / 1 gwei;

        ObolValidatorManager ovm = factory.createObolValidatorManager(
            owner,
            principalRecipient,
            rewardsRecipient,
            principalThreshold
        );

        require(ovm.owner() == deployerAddress, "ObolValidatorManager got wrong owner!");

        console.log("ObolValidatorManager created at address: ", address(ovm));

        vm.stopBroadcast();
    }
}
