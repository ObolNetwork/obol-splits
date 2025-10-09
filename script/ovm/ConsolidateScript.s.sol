// SPDX-License-Identifier: Proprietary
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "./Utils.s.sol";
import {ObolValidatorManager} from "src/ovm/ObolValidatorManager.sol";
import {IObolValidatorManager} from "src/interfaces/IObolValidatorManager.sol";

//
// This script calls consolidate() for an ObolValidatorManager contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
//
contract ConsolidateScript is Script {
  function run(address ovmAddress, bytes calldata src, bytes calldata dst) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    if (privKey == 0) {
      revert("set PRIVATE_KEY env var before using this script");
    }
    if (!Utils.isContract(ovmAddress)) {
      revert("Invalid OVM address");
    }
    if (src.length == 0 || dst.length == 0) {
      revert("Invalid source or destination pubkey");
    }

    vm.startBroadcast(privKey);

    ObolValidatorManager ovm = ObolValidatorManager(payable(ovmAddress));

    bytes[] memory sourcePubKeys = new bytes[](1);
    sourcePubKeys[0] = src;

    IObolValidatorManager.ConsolidationRequest[] memory requests = new IObolValidatorManager.ConsolidationRequest[](1);
    requests[0] = IObolValidatorManager.ConsolidationRequest({srcPubKeys: sourcePubKeys, targetPubKey: dst});
    
    ovm.consolidate{value: 100 wei}(requests, 100 wei, msg.sender);

    vm.stopBroadcast();
  }
}
