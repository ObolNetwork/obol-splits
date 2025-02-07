// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ObolValidatorManagerFactory} from "src/ovm/ObolValidatorManagerFactory.sol";

//
// This script deploys a new ObolValidatorManagerFactory contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
// Please set ensReverseRegistrar before running this script.
// Example usage:
//   forge script script/ObolValidatorManagerFactoryScript.s.sol --sig "run(string)"
//   --rpc-url https://rpc.pectra-devnet-5.ethpandaops.io/ --broadcast "demo"
//
contract ObolValidatorManagerFactoryScript is Script {
  // From https://github.com/ethereum/EIPs/blob/d96625a4dcbbe2572fa006f062bd02b4582eefd5/EIPS/eip-7251.md#execution-layer
  address constant consolidationSysContract = 0x00431F263cE400f4455c2dCf564e53007Ca4bbBb;
  // From https://github.com/ethereum/EIPs/blob/d96625a4dcbbe2572fa006f062bd02b4582eefd5/EIPS/eip-7002.md#configuration
  address constant withdrawalSysContract = 0x0c15F14308530b7CDB8460094BbB9cC28b9AaaAA;
  // By default the script is aiming devnet
  address constant depositSysContract = 0x4242424242424242424242424242424242424242;
  // TBD
  address ensReverseRegistrar = address(0);

  function run(string calldata name) external {
    if (ensReverseRegistrar == address(0)) 
      revert("update ensReverseRegistrar & depositSysContract before using this script");

    uint256 privKey = vm.envUint("PRIVATE_KEY");

    vm.startBroadcast(privKey);

    ObolValidatorManagerFactory factory = new ObolValidatorManagerFactory{salt: keccak256(bytes(name))}(
      consolidationSysContract,
      withdrawalSysContract,
      depositSysContract,
      name,
      ensReverseRegistrar,
      msg.sender
    );

    console.log("ObolValidatorManagerFactory deployed at: ", address(factory));

    vm.stopBroadcast();
  }
}
