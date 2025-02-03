// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {OptimisticWithdrawalRecipientV2Factory} from "../src/owr/OptimisticWithdrawalRecipientV2Factory.sol";

//
// This script creates a new OptimisticWithdrawalRecipientV2 contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
// Example usage:
//   forge script script/CreateOWRecipientScript.s.sol --sig "run(address)" \
//   --rpc-url https://rpc.pectra-devnet-5.ethpandaops.io/ --broadcast "<factory_address>"
//
contract CreateOWRecipientScript is Script {
    function run(address deployedOWRV2Factory) external {
        uint256 privKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privKey);

        OptimisticWithdrawalRecipientV2Factory factory = OptimisticWithdrawalRecipientV2Factory(deployedOWRV2Factory);

        address recoveryAddress = msg.sender;
        address principalRecipient = msg.sender;
        address rewardsRecipient = msg.sender;
        uint256 trancheThreshold = 16 ether;
        address owner = msg.sender;

        // Call the createOWRecipient function
        factory.createOWRecipient(
            recoveryAddress,
            principalRecipient,
            rewardsRecipient,
            trancheThreshold,
            owner
        );

        vm.stopBroadcast();
    }
}