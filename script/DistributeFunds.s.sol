// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {OptimisticWithdrawalRecipientV2} from "src/owr/OptimisticWithdrawalRecipientV2.sol";

//
// This script calls distributeFunds() for a OptimisticWithdrawalRecipientV2 contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
// Example usage:
//   forge script script/DistributeFunds.s.sol --sig "run(address)" \
//   --rpc-url https://rpc.pectra-devnet-5.ethpandaops.io/ --broadcast "<owrv2_address>"
//
contract DistributeFunds is Script {
    function run(address deployedOWRV2) external {
        uint256 privKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privKey);

        OptimisticWithdrawalRecipientV2 owr = OptimisticWithdrawalRecipientV2(deployedOWRV2);
        owr.distributeFunds();

        vm.stopBroadcast();
    }
}