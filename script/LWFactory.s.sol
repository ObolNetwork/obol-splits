// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";
import {LWFactory} from "src/waterfall/LWFactory.sol";

contract LWFactoryScript is Script {
  function run(address waterfallFactoryModule, address splitMain, address ensReverseRegistrar, address ensOnwer)
    external
  {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(privKey);

    string memory ensName = "lwfactory.obol.eth";

    new LWFactory{salt: keccak256("obol.lwFactory.v1")}(
            waterfallFactoryModule,
            splitMain,
            ensName,
            ensReverseRegistrar,
            ensOnwer
        );
    vm.stopBroadcast();
  }
}
