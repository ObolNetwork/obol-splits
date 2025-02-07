// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {ObolValidatorManager} from "src/ovm/ObolValidatorManager.sol";

//
// This script calls deposit() on a ObolValidatorManager contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
// Example usage:
//   forge script script/DepositScript.s.sol --sig "run(address)" \
//   --rpc-url https://rpc.pectra-devnet-5.ethpandaops.io/ --broadcast "<ovm_address>"
//
contract DepositScript is Script {
    function run(address ovmAddress) external {
        uint256 privKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privKey);

        ObolValidatorManager ovm = ObolValidatorManager(payable(ovmAddress));

        // Update these values from the deposit_data json file
        bytes memory pubkey = hex"b44006ca9c0af2d763fd08d6f25ef69b8293cd8d4ec205b4e916e73322a73e08b1947dd2ae07b21b48f37f51aea9fc5b";
        bytes memory withdrawal_credentials = hex"010000000000000000000000e475c6c58f0366cf3813fd95a5522fe2bbe4472b";
        bytes memory signature = hex"8637046854d2e1b61974b1ab88c1d475b81af8bbaff82f183a924bab416eafa59916ea614ba384687c9cbaa6f6e1494a12e827fe4e9041595b98b262ff65ad88bcc337b981f0ecc8febe8d55d15bcaca6295df53bffbae75c12ebf79fd9da469";
        bytes32 deposit_data_root = hex"c7509d78f68f4b507bece68369de7d791bccd32d92eb3816a6fb65d2d84c4158";
        ovm.deposit{value: 32 ether}(pubkey, withdrawal_credentials, signature, deposit_data_root);

        vm.stopBroadcast();
    }
}