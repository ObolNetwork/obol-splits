// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {PullSplitMock} from "src/test/owr/mocks/PullSplitMock.sol";

contract DeployPullSplitMock is Script {
  function run() external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    
    vm.startBroadcast(privKey);

    new PullSplitMock{salt: keccak256("pullSplitMock.1")}();

    vm.stopBroadcast();
  }
}