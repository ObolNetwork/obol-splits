// SPDX-License-Identifier: NONE
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "script/ovm/Utils.s.sol";
import {ObolValidatorManagerFactory} from "src/ovm/ObolValidatorManagerFactory.sol";
import {ObolValidatorManager} from "src/ovm/ObolValidatorManager.sol";

//
// This script creates a new instance of the ObolValidatorManager contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
// The first script parameter is the deployed ObolValidatorManagerFactory contract.
// You need to either deploy one using DeployFactoryScript, or the predeployed one by Obol:
// https://docs.obol.org/next/learn/readme/obol-splits#obol-validator-manager-factory-deployment
//
contract CreateOVMScript is Script {
  function run(
    address ovmFactory,
    address owner,
    address beneficiary,
    address rewardRecipient,
    uint64 principalThreshold
  ) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    if (privKey == 0) revert("set PRIVATE_KEY env var before using this script");
    if (!Utils.isContract(ovmFactory)) revert("OVM Factory address is not set or invalid");
    if (owner == address(0)) revert("Owner address cannot be zero");
    if (beneficiary == address(0)) revert("Beneficiary recipient address cannot be zero");
    if (rewardRecipient == address(0)) revert("Reward recipient address cannot be zero");
    if (principalThreshold == 0) revert("Principal threshold cannot be zero");

    vm.startBroadcast(privKey);

    ObolValidatorManagerFactory factory = ObolValidatorManagerFactory(ovmFactory);
    ObolValidatorManager ovm =
      factory.createObolValidatorManager(owner, beneficiary, rewardRecipient, principalThreshold);

    console.log("ObolValidatorManager created at address", address(ovm));
    Utils.printExplorerUrl(address(ovm));

    vm.stopBroadcast();
  }
}
