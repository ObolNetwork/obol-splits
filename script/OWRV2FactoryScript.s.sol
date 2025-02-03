// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {OptimisticWithdrawalRecipientV2Factory} from "src/owr/OptimisticWithdrawalRecipientV2Factory.sol";

//
// This script deploys a new OptimisticWithdrawalRecipientV2Factory contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
// Please set ensReverseRegistrar before running this script.
// Example usage:
//   forge script script/OWRV2FactoryScript.s.sol --sig "run(string)" 
//   --rpc-url https://rpc.pectra-devnet-5.ethpandaops.io/ --broadcast "demo"
//
contract OWRV2FactoryScript is Script {
  // From https://github.com/ethereum/EIPs/blob/d96625a4dcbbe2572fa006f062bd02b4582eefd5/EIPS/eip-7251.md#execution-layer
  address constant consolidationSysContract = 0x00431F263cE400f4455c2dCf564e53007Ca4bbBb;
  // From https://github.com/ethereum/EIPs/blob/d96625a4dcbbe2572fa006f062bd02b4582eefd5/EIPS/eip-7002.md#configuration
  address constant withdrawalSysContract = 0x0c15F14308530b7CDB8460094BbB9cC28b9AaaAA;

  // TBD
  address ensReverseRegistrar = address(0x0);

  function run(string calldata name) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");

    if (ensReverseRegistrar == address(0x0)) {
      revert("ensReverseRegistrar not set");
    }
    
    vm.startBroadcast(privKey);
    
    new OptimisticWithdrawalRecipientV2Factory{salt: keccak256(bytes(name))}(
      name,
      ensReverseRegistrar,
      msg.sender,
      consolidationSysContract,
      withdrawalSysContract
    );

    vm.stopBroadcast();
  }
}
