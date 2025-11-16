// SPDX-License-Identifier: NONE
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "./Utils.s.sol";
import {ObolValidatorManager} from "src/ovm/ObolValidatorManager.sol";

//
// This script calls sweep() for an ObolValidatorManager contract.
// The sweep function allows sweeping funds from the pull balance to a recipient.
// - If beneficiary is address(0), funds are swept to the principal recipient (no owner check required)
// - If beneficiary is specified, only owner can call and funds are swept to that address
// - If amount is 0, all available pull balance for principal recipient is swept
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
//
contract SweepScript is Script {
  function run(address ovmAddress, address beneficiary, uint256 amount) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    if (privKey == 0) revert("set PRIVATE_KEY env var before using this script");
    if (!Utils.isContract(ovmAddress)) revert("OVM address is not set or invalid");

    vm.startBroadcast(privKey);

    ObolValidatorManager ovm = ObolValidatorManager(payable(ovmAddress));

    console.log("OVM address:", ovmAddress);
    console.log("--- State Before Sweep ---");
    address principalRecipient = ovm.getBeneficiary();
    console.log("Principal recipient: %s", principalRecipient);
    console.log("Pull balance for principal recipient: %d gwei", ovm.getPullBalance(principalRecipient) / 1 gwei);
    console.log("Funds pending withdrawal: %d gwei", ovm.fundsPendingWithdrawal() / 1 gwei);

    if (beneficiary == address(0)) {
      console.log("Sweeping to principal recipient (no beneficiary override)");
      if (amount == 0) console.log("Amount: ALL available pull balance");
      else console.log("Amount to sweep: %d gwei", amount / 1 gwei);
    } else {
      console.log("Sweeping to custom beneficiary: %s", beneficiary);
      if (amount == 0) console.log("Amount: ALL available pull balance");
      else console.log("Amount to sweep: %d gwei", amount / 1 gwei);
    }

    console.log("--- Executing Sweep ---");
    ovm.sweep(beneficiary, amount);

    console.log("--- State After Sweep ---");
    console.log("Pull balance for principal recipient: %d gwei", ovm.getPullBalance(principalRecipient) / 1 gwei);
    console.log("Funds pending withdrawal: %d gwei", ovm.fundsPendingWithdrawal() / 1 gwei);
    console.log("Sweep completed successfully");

    vm.stopBroadcast();
  }
}
