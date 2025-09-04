// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "./Utils.s.sol";
import {ObolValidatorManager} from "src/ovm/ObolValidatorManager.sol";

//
// This script calls setAmountOfPrincipalStake() for an ObolValidatorManager contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
//
contract SetAmountOfPrincipalStakeScript is Script {
  function run(address ovmAddress, uint256 newAmount) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    if (privKey == 0) {
      revert("set PRIVATE_KEY env var before using this script");
    }
    if (!Utils.isContract(ovmAddress)) {
      revert("OVM address is not set or invalid");
    }

    vm.startBroadcast(privKey);

    ObolValidatorManager ovm = ObolValidatorManager(payable(ovmAddress));

    console.log("Current amount of principal stake", ovm.amountOfPrincipalStake());

    ovm.setAmountOfPrincipalStake(newAmount);

    console.log("New amount of principal stake", ovm.amountOfPrincipalStake());

    vm.stopBroadcast();
  }
}
