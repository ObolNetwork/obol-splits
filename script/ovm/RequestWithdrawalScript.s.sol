// SPDX-License-Identifier: Proprietary
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "./Utils.s.sol";
import {ObolValidatorManager} from "src/ovm/ObolValidatorManager.sol";

//
// This script calls requestWithdrawal() for an ObolValidatorManager contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
//
contract RequestWithdrawalScript is Script {
  function run(address ovmAddress, bytes calldata pubkey, uint64 amount) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    if (privKey == 0) {
      revert("set PRIVATE_KEY env var before using this script");
    }
    if (!Utils.isContract(ovmAddress)) {
      revert("Invalid OVM address");
    }
    if (amount == 0) {
      revert("Invalid withdrawal amount");
    }

    vm.startBroadcast(privKey);

    ObolValidatorManager ovm = ObolValidatorManager(payable(ovmAddress));

    bytes[] memory pubKeys = new bytes[](1);
    pubKeys[0] = pubkey;

    uint64[] memory amounts = new uint64[](1);
    amounts[0] = amount;

    ovm.requestWithdrawal{value: 100 wei}(pubKeys, amounts);

    vm.stopBroadcast();
  }
}
