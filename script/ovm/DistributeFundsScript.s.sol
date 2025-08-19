// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "./Utils.s.sol";
import {ObolValidatorManager} from "src/ovm/ObolValidatorManager.sol";

//
// This script calls distributeFunds() for a ObolValidatorManager contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
//
contract DistributeFundsScript is Script {
  function run(address ovmAddress) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    if (privKey == 0) {
      revert("set PRIVATE_KEY env var before using this script");
    }
    if (!Utils.isContract(ovmAddress)) {
      revert("OVM address is not set or invalid");
    }

    vm.startBroadcast(privKey);

    ObolValidatorManager ovm = ObolValidatorManager(payable(ovmAddress));
    ovm.distributeFunds();

    vm.stopBroadcast();
  }
}
