// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {DepositContractMock} from "src/test/owr/mocks/DepositContractMock.sol";

contract DeployMockDepositContract is Script {
  function run() external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    
    vm.startBroadcast(privKey);

    new DepositContractMock{salt: keccak256("depositContractMock")}();

    vm.stopBroadcast();
  }
}