// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {OptimisticWithdrawalRecipientV2} from "src/owr/OptimisticWithdrawalRecipientV2.sol";

//
// This script calls requestWithdrawal() for a OptimisticWithdrawalRecipientV2 contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
// Example usage:
//   forge script script/RequestWithdrawal.s.sol --sig "run(address,bytes,bytes)" \
//     --rpc-url https://rpc.pectra-devnet-5.ethpandaops.io/ --broadcast \
//     "<owrv2_address>" "<pubkey>" "<amount_gwei>"
//
contract RequestWithdrawal is Script {
    function run(address owrv2, bytes calldata pubkey, uint64 amount) external {
        uint256 privKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privKey);

        OptimisticWithdrawalRecipientV2 owr = OptimisticWithdrawalRecipientV2(payable(owrv2));

        bytes[] memory pubKeys = new bytes[](1);
        pubKeys[0] = pubkey;

        uint64[] memory amounts = new uint64[](1);
        amounts[0] = amount;

        // Estimated total gas used for script: 219325
        owr.requestWithdrawal{value: 100 wei}(pubKeys, amounts);

        vm.stopBroadcast();
    }
}