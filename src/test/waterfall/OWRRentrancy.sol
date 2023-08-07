// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {OptimisticWithdrawalRecipient} from "src/waterfall/OptimisticWithdrawalRecipient.sol";

contract OWRReentrancy {
    receive() external payable {
        if (address(this).balance <= 1 ether) {
            OptimisticWithdrawalRecipient(msg.sender).distributedFunds();
        }
    }
}
