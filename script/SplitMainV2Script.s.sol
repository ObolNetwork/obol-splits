// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";
import {SplitMainV2} from "src/splitter/SplitMainV2.sol";

contract SplitMainV2Script is Script {
  function run()
    external
  {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(privKey);

    new SplitMainV2{salt: keccak256("obol.splitMainV2.v1")}();
    
    vm.stopBroadcast();
  }
}
