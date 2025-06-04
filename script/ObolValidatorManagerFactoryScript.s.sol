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
//   --rpc-url https://rpc.hoodi.ethpandaops.io --broadcast "demo"
//
contract ObolValidatorManagerFactoryScript is Script {
  // From https://github.com/ethereum/EIPs/blob/master/EIPS/eip-7251.md
  address constant consolidationSysContract = 0x0000BBdDc7CE488642fb579F8B00f3a590007251;
  // From https://github.com/ethereum/EIPs/blob/master/EIPS/eip-7002.md
  address constant withdrawalSysContract = 0x00000961Ef480Eb55e80D19ad83579A64c007002;
  // By default the script is aiming mainnet/hoodi
  address constant depositSysContract = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
  // ENS deployments: https://docs.ens.domains/learn/deployments/
  address ensReverseRegistrar = 0xa58E81fe9b61B5c3fE2AFD33CF304c454AbFc7Cb;

  function run(string calldata name) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    if (privKey == 0) revert("set PRIVATE_KEY env var before using this script");

    address ensOwner = vm.addr(privKey);

    vm.startBroadcast(privKey);

    ObolValidatorManagerFactory factory = new ObolValidatorManagerFactory{salt: keccak256(bytes(name))}(
      consolidationSysContract,
      withdrawalSysContract,
      depositSysContract,
      name,
      ensReverseRegistrar,
      ensOwner
    );

    console.log("ObolValidatorManagerFactory deployed at: ", address(factory));

    vm.stopBroadcast();
  }
}
