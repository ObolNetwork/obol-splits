// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "solmate/auth/Auth.sol";

import { WithdrawalRecipientOwnable } from "../../src/WithdrawalRecipientOwnable.sol";

contract MockWithdrawalRecipient is WithdrawalRecipientOwnable(msg.sender, Authority(address(0))) {}