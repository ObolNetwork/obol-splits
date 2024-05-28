// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {OptimisticTokenWithdrawalRecipientFactory} from "src/owr/token/OptimisticTokenWithdrawalRecipientFactory.sol";

contract OWRWFactoryWithTokenScript is Script {
  uint256 constant ETH_STAKE_THRESHOLD = 16 ether;
  uint256 constant GNO_STAKE_THRESHOLD = 0.8 ether;

  function run() external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");

    vm.startBroadcast(privKey);

    new OptimisticTokenWithdrawalRecipientFactory{salt: keccak256("obol.owrFactoryWithToken.v0.0")}(GNO_STAKE_THRESHOLD);

    vm.stopBroadcast();
  }
}
