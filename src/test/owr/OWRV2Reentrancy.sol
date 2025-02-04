// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {OptimisticWithdrawalRecipientV2} from "src/owr/OptimisticWithdrawalRecipientV2.sol";

contract OWRV2Reentrancy is Test {
  receive() external payable {
    console.log("OWRV2Reentrancy::receive() with value", msg.value, "and balance", address(this).balance);

    if (address(this).balance <= 1 ether) OptimisticWithdrawalRecipientV2(payable(msg.sender)).distributeFunds();
  }
}
