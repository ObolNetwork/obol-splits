// SPDX-License-Identifier: Proprietary
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "./Utils.s.sol";
import {ObolValidatorManager} from "src/ovm/ObolValidatorManager.sol";

//
// This script calls setRewardRecipient() for an ObolValidatorManager contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
//
contract SetRewardRecipientScript is Script {
  function run(address ovmAddress, address newRewardRecipient) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    if (privKey == 0) {
      revert("set PRIVATE_KEY env var before using this script");
    }
    if (!Utils.isContract(ovmAddress)) {
      revert("OVM address is not set or invalid");
    }
    if (newRewardRecipient == address(0)) {
      revert("New reward recipient address cannot be zero");
    }

    vm.startBroadcast(privKey);

    ObolValidatorManager ovm = ObolValidatorManager(payable(ovmAddress));

    console.log("Current reward recipient", ovm.rewardRecipient());

    ovm.setRewardRecipient(newRewardRecipient);

    console.log("New reward recipient set to", ovm.rewardRecipient());

    vm.stopBroadcast();
  }
}
