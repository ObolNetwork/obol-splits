// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {ObolTechneCredentials} from "src/techne/ObolTechneCredentials.sol";

contract ObolTechneCredentialsScript is Script {
  function run() external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    address pubKey = vm.envAddress("PUBLIC_KEY");

    vm.startBroadcast(privKey);

    new ObolTechneCredentials{salt: keccak256("obol.obolTechneCredentialsTest.v1.gold")}(
      "Obol Techne Credentials", "OTC", "https://api.obol.tech/techne/gold/", pubKey
    );

    vm.stopBroadcast();
  }
}
