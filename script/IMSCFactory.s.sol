// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {ImmutableSplitControllerFactory} from "src/controllers/ImmutableSplitControllerFactory.sol";

contract IMSCFactoryScript is Script {
  function run(address) external {
    address SPLIT_MAIN_GOERLI = 0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE;

    uint256 privKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(privKey);

    new ImmutableSplitControllerFactory{salt: keccak256("obol.imsc.v1")}(SPLIT_MAIN_GOERLI);

    vm.stopBroadcast();
  }
}
