// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Script.sol";
import {SplitWallet} from "src/splitter/SplitWallet.sol";

contract SplitWalletScript is Script {
  function run(address splitMainV2)
    external
  {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(privKey);

    new SplitWallet{salt: keccak256("obol.splitWallet.v1")}(splitMainV2);
    
    vm.stopBroadcast();
  }
}
