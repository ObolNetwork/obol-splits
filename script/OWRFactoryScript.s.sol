// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {OptimisticWithdrawalRecipientFactory} from "src/owr/OptimisticWithdrawalRecipientFactory.sol";

contract OWRFactoryScript is Script {
  function run(string memory _name, address _ensReverseRegistrar, address _ensOwner) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");

    vm.startBroadcast(privKey);

    new OptimisticWithdrawalRecipientFactory{salt: keccak256("obol.owrFactory.v1")}(
      _name, _ensReverseRegistrar, _ensOwner
    );

    vm.stopBroadcast();
  }
}
