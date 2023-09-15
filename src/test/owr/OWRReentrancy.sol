// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {OptimisticWithdrawalRecipient} from "src/owr/OptimisticWithdrawalRecipient.sol";

contract OWRReentrancy is Test {
  receive() external payable {
    if (address(this).balance <= 1 ether) OptimisticWithdrawalRecipient(msg.sender).distributeFunds();
  }
}
