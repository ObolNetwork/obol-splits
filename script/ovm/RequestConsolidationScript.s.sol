// SPDX-License-Identifier: Proprietary
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "./Utils.s.sol";
import {ObolValidatorManager} from "src/ovm/ObolValidatorManager.sol";

//
// This script calls requestConsolidation() for an ObolValidatorManager contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
//
contract RequestConsolidationScript is Script {
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

    ovm.requestConsolidation{value: 100 wei}(sourcePubKeys, dst);

    vm.stopBroadcast();
  }
}
