// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {ObolValidatorManager} from "src/ovm/ObolValidatorManager.sol";

//
// This script calls requestWithdrawal() for a ObolValidatorManager contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
// Example usage:
//   forge script script/RequestWithdrawalScript.s.sol --sig "run(address,bytes,bytes)" \
//     --rpc-url https://rpc.pectra-devnet-5.ethpandaops.io/ --broadcast \
//     "<ovm_address>" "<pubkey>" "<amount_gwei>"
//
contract RequestWithdrawalScript is Script {
    function run(address ovmAddress, bytes calldata pubkey, uint64 amount) external {
        uint256 privKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privKey);

        ObolValidatorManager ovm = ObolValidatorManager(payable(ovmAddress));

        bytes[] memory pubKeys = new bytes[](1);
        pubKeys[0] = pubkey;

        uint64[] memory amounts = new uint64[](1);
        amounts[0] = amount;

        // Estimated total gas used for script: 219325
        ovm.requestWithdrawal{value: 100 wei}(pubKeys, amounts);

        vm.stopBroadcast();
    }
}