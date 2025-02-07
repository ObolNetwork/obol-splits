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

// forge script script/RequestConsolidationScript.s.sol --sig "run(address,bytes,bytes)" --rpc-url https://rpc.pectra-devnet-5.ethpandaops.io/ --broadcast "0xe475c6c58f0366cf3813fd95a5522fe2BbE4472b" "84f1150a83ee050668f5c4d96d5d2cc1d5e19af297840bee6614371ce67960c149b60aab4c3bba3dae13704c14e220c9" "b44006ca9c0af2d763fd08d6f25ef69b8293cd8d4ec205b4e916e73322a73e08b1947dd2ae07b21b48f37f51aea9fc5b"