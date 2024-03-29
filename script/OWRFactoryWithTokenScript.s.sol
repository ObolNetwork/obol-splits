// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {OptimisticWithdrawalWithTokenRecipientFactory} from "src/owr/token/OptimisticWithdrawalWithTokenRecipientFactory.sol";

contract OWRWFactoryWithTokenScript is Script {
  function run() external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    
    vm.startBroadcast(privKey);
    
    new OptimisticWithdrawalWithTokenRecipientFactory{salt: keccak256("obol.owrFactoryWithToken.v1")}();

    vm.stopBroadcast();
  }
}
