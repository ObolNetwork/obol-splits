// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ObolValidatorManager} from "src/ovm/ObolValidatorManager.sol";

//
// This script calls setPrincipalRecipient() for a ObolValidatorManager contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
// Example usage:
//   forge script script/SetPrincipalRecipientScript.s.sol --sig "run(address,address)" \
//     --rpc-url https://rpc.pectra-devnet-5.ethpandaops.io/ --broadcast \
//     "<ovm_address>" "<new_principal_recipient>" -vvv
//
contract SetPrincipalRecipientScript is Script {
  function run(address ovmAddress, address newPrincipalRecipient) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    if (privKey == 0) revert("set PRIVATE_KEY env var before using this script");

    vm.startBroadcast(privKey);

    ObolValidatorManager ovm = ObolValidatorManager(payable(ovmAddress));

    console.log("Current principal recipient: ", ovm.principalRecipient());

    ovm.setPrincipalRecipient(newPrincipalRecipient);

    console.log("New principal recipient set to: ", ovm.principalRecipient());

    vm.stopBroadcast();
  }
}
