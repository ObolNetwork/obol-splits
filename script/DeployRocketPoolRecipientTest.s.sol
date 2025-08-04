// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {ObolRocketPoolRecipientFactory} from "src/rocket-pool/ObolRocketPoolRecipientFactory.sol";
import {ISplitMain, SplitConfiguration} from "src/interfaces/ISplitMain.sol";
import {SplitterConfiguration} from "./SplitterConfiguration.sol";

contract DeployRocketPoolRecipientTest is Script, SplitterConfiguration {
  error Invalid_PrincipalRecipient();

  function run()
    external
  {
    address rpRecipientFactory = 0xd1B952171DF38A209326f8DF6C8Da1226C18995A; 
    uint256 privKey = vm.envUint("PRIVATE_KEY");

    address recipient = vm.envAddress("PUBLIC_KEY");

    vm.startBroadcast(privKey);

    address rocketPoolRecipientAddress = address(
      ObolRocketPoolRecipientFactory(rpRecipientFactory).createObolRocketPoolRecipient(
        recipient, recipient, recipient, 8 ether
      )
    );
    vm.stopBroadcast();

    string memory repsonse = vm.serializeAddress("rpRecipient", "ObolRocketPoolRecipient", rocketPoolRecipientAddress);
    string memory finalJSON = vm.serializeString("rocket-pool-deployment", "rpRecipient", repsonse);
    vm.writeJson(finalJSON, "./rocket-pool-recipient-split.json");
  }
}