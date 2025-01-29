// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {OptimisticWithdrawalRecipientV2} from "src/owr/OptimisticWithdrawalRecipientV2.sol";

//
// This script calls requestConsolidation() for a OptimisticWithdrawalRecipientV2 contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
// Example usage:
//   forge script script/RequestConsolidation.s.sol --sig "run(address,bytes,bytes)" \
//     --rpc-url https://rpc.pectra-devnet-5.ethpandaops.io/ --broadcast \
//     "<owrv2_address>" "<src_pubkey>" "<dst_pubkey>"
//
contract RequestConsolidation is Script {
    function run(address owrv2, bytes calldata src, bytes calldata dst) external {
        uint256 privKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privKey);

        OptimisticWithdrawalRecipientV2 owr = OptimisticWithdrawalRecipientV2(owrv2);

        // Call the function on the deployed contract
        bytes[] memory sourcePubKeys = new bytes[](1);
        sourcePubKeys[0] = src;

        // Estimated total gas used for script: 162523
        owr.requestConsolidation{value: 100 wei}(sourcePubKeys, dst);

        vm.stopBroadcast();
    }
}