// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "script/ovm/Utils.s.sol";
import {ObolValidatorManagerFactory} from "src/ovm/ObolValidatorManagerFactory.sol";

//
// This script deploys the ObolValidatorManagerFactory contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
// Please verify the addresses below before running the script!
//
contract DeployFactoryScript is Script {
  // From https://github.com/ethereum/EIPs/blob/master/EIPS/eip-7251.md
  address constant consolidationSysContract = 0x0000BBdDc7CE488642fb579F8B00f3a590007251;
  // From https://github.com/ethereum/EIPs/blob/master/EIPS/eip-7002.md
  address constant withdrawalSysContract = 0x00000961Ef480Eb55e80D19ad83579A64c007002;
  // By default the script is aiming mainnet or major testnets, but not devnets.
  // For devnets use 0x4242424242424242424242424242424242424242
  address constant depositSysContract = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
  // ENS deployments: https://docs.ens.domains/learn/deployments/
  // Mainnet: 0xa58E81fe9b61B5c3fE2AFD33CF304c454AbFc7Cb
  // Sepolia: 0xA0a1AbcDAe1a2a4A2EF8e9113Ff0e02DD81DC0C6
  // Holesky: 0x132AC0B116a73add4225029D1951A9A707Ef673f
  address ensReverseRegistrar = 0xA0a1AbcDAe1a2a4A2EF8e9113Ff0e02DD81DC0C6;

  function run(string calldata name) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    if (privKey == 0) {
      revert("set PRIVATE_KEY env var before using this script");
    }
    if (!Utils.isContract(ensReverseRegistrar)) {
      revert("ENS Reverse Registrar address is not set or invalid");
    }

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

    console.log("ObolValidatorManagerFactory deployed at", address(factory));
    Utils.printExplorerUrl(address(factory));

    vm.stopBroadcast();
  }
}
