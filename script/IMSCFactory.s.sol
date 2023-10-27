// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {ImmutableSplitControllerFactory} from "src/controllers/ImmutableSplitControllerFactory.sol";

contract IMSCFactoryScript is Script {
  function run(address splitMain) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(privKey);

    new ImmutableSplitControllerFactory{salt: keccak256("obol.imsc.v1")}(splitMain);

    vm.stopBroadcast();
  }
}
