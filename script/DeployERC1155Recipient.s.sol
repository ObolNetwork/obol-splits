// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {ObolErc1155Recipient} from "src/owr/ObolErc1155Recipient.sol";

contract DeployERC1155Recipient is Script {

  // @dev `_depositContract` is passed to allow 
  function run(string memory _baseUri, address _owner, address _depositContract) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    
    vm.startBroadcast(privKey);

    new ObolErc1155Recipient{salt: keccak256("owr.erc1155recipient")}(_baseUri, _owner, _depositContract);

    vm.stopBroadcast();
  }
}
