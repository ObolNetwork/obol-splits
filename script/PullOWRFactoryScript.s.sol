// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {OptimisticPullWithdrawalRecipientFactory} from "src/owr/OptimisticPullWithdrawalRecipientFactory.sol";

contract PullOWRFactoryScript is Script {
  function run() external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");

    string memory _name = "HoleskyTest";
    address _ensReverseRegistrar = address(0x132AC0B116a73add4225029D1951A9A707Ef673f);
    address _ensOwner = vm.envAddress("PUBLIC_KEY");

    vm.startBroadcast(privKey);

    new OptimisticPullWithdrawalRecipientFactory{salt: keccak256("obol.pullOwrFactory.v1.holesky")}(
      _name, _ensReverseRegistrar, _ensOwner
    );

    vm.stopBroadcast();
  }
}
