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
        bytes memory pubkey = hex"b9224aa98e2ad166bb4bf31109dfab36a938f5bf7d88c79971227d4ee03d35fd21cea4fc1aa5f87c199e82ceab521842";
        bytes memory withdrawal_credentials = hex"01000000000000000000000002a362103abde4c712c27d626195a2a5e442b253";
        bytes memory signature = hex"a7c34d447dfdfd71fc43f1605e20545072d2d9ad8df365432686e8482e7b1aadc90a76fc0fbc96d9f359636dcd6902911654bf18e4d71b06c86815b0aef3bd0f187526960e6d92c4a8e9321c62aa4e96440b47b4b827dc9d24eedaca9d4c13df";
        bytes32 deposit_data_root = hex"20144d020e7638d583970f708c8abc7c0066b73cf08a23425a6ce48a1222c513";
        ovm.deposit{value: 32 ether}(pubkey, withdrawal_credentials, signature, deposit_data_root);

        vm.stopBroadcast();
    }
}
