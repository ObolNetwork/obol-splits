// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";
import {SplitFactory} from "src/splitter/SplitFactory.sol";

contract SplitFactoryScript is Script {
  function run(address owner) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(privKey);

    new SplitFactory{salt: keccak256("obol.splitFactory.v1")}(owner);

    vm.stopBroadcast();
  }
}
