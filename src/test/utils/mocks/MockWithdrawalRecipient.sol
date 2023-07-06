// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "solmate/auth/Auth.sol";

import {WithdrawalRecipientOwnable} from "src/archive/WithdrawalRecipientOwnable.sol";

contract MockWithdrawalRecipient is WithdrawalRecipientOwnable(msg.sender, Authority(address(0))) {}
