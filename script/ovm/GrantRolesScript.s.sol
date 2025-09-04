// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "./Utils.s.sol";
import {ObolValidatorManager} from "src/ovm/ObolValidatorManager.sol";

//
// This script calls grantRoles() for an ObolValidatorManager contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
//
contract GrantRolesScript is Script {
  function run(address ovmAddress, address account, uint256 roles) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    if (privKey == 0) {
      revert("set PRIVATE_KEY env var before using this script");
    }
    if (!Utils.isContract(ovmAddress)) {
      revert("OVM address is not set or invalid");
    }
    if (account == address(0)) {
      revert("Account address cannot be zero");
    }
    if (roles == 0) {
      revert("Roles cannot be zero");
    }

    vm.startBroadcast(privKey);

    ObolValidatorManager ovm = ObolValidatorManager(payable(ovmAddress));
    ovm.grantRoles(account, roles);

    console.log("New roles for account", ovm.rolesOf(account));

    vm.stopBroadcast();
  }
}
