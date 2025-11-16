// SPDX-License-Identifier: NONE
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "./Utils.s.sol";
import {ObolValidatorManager} from "src/ovm/ObolValidatorManager.sol";

//
// This script calls distributeFunds() for an ObolValidatorManager contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
//
contract DistributeFundsScript is Script {
  function run(address ovmAddress) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    if (privKey == 0) revert("set PRIVATE_KEY env var before using this script");
    if (!Utils.isContract(ovmAddress)) revert("OVM address is not set or invalid");

    vm.startBroadcast(privKey);

    ObolValidatorManager ovm = ObolValidatorManager(payable(ovmAddress));

    console.log("OVM address:", ovmAddress);
    console.log("--- State Before Distribution ---");
    console.log("OVM balance: %d gwei", address(ovm).balance / 1 gwei);
    console.log("Amount of principal stake: %d gwei", ovm.amountOfPrincipalStake() / 1 gwei);
    console.log("Funds pending withdrawal: %d gwei", ovm.fundsPendingWithdrawal() / 1 gwei);
    console.log("Principal threshold: %d gwei", ovm.principalThreshold());
    console.log("Beneficiary (principal recipient): %s", ovm.getBeneficiary());
    console.log("Reward recipient: %s", ovm.rewardRecipient());

    console.log("--- Distributing Funds ---");
    ovm.distributeFunds();

    console.log("--- State After Distribution ---");
    console.log("Amount of principal stake: %d gwei", ovm.amountOfPrincipalStake() / 1 gwei);
    console.log("Distribution completed successfully");

    vm.stopBroadcast();
  }
}
