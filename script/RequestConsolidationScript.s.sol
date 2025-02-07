// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {ObolValidatorManager} from "src/ovm/ObolValidatorManager.sol";

//
// This script calls requestConsolidation() for a ObolValidatorManager contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
// Example usage:
//   forge script script/RequestConsolidationScript.s.sol --sig "run(address,bytes,bytes)" \
//     --rpc-url https://rpc.pectra-devnet-5.ethpandaops.io/ --broadcast \
//     "<ovm_address>" "<src_pubkey>" "<dst_pubkey>"
//
contract RequestConsolidationScript is Script {
    function run(address ovmAddress, bytes calldata src, bytes calldata dst) external {
        uint256 privKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privKey);

        ObolValidatorManager ovm = ObolValidatorManager(payable(ovmAddress));

        // Call the function on the deployed contract
        bytes[] memory sourcePubKeys = new bytes[](1);
        sourcePubKeys[0] = src;

        ovm.requestConsolidation{value: 100 wei}(sourcePubKeys, dst);

        vm.stopBroadcast();
    }
}
