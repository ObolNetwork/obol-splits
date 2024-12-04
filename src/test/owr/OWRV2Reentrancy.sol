// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {OptimisticWithdrawalRecipientV2} from "src/owr/OptimisticWithdrawalRecipientV2.sol";

contract OWRV2Reentrancy is Test {
  receive() external payable {
    if (address(this).balance <= 1 ether) OptimisticWithdrawalRecipientV2(msg.sender).distributeFunds();
  }
}
