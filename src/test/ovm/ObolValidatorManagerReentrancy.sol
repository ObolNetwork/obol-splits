// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {ObolValidatorManager} from "src/ovm/ObolValidatorManager.sol";

contract ObolValidatorManagerReentrancy is Test {
  receive() external payable {
    console.log("receive() with value", msg.value, "and balance", address(this).balance);

    if (address(this).balance <= 1 ether) ObolValidatorManager(payable(msg.sender)).distributeFunds();
  }
}
