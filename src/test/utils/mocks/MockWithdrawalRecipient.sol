// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "solmate/auth/Auth.sol";

import { WithdrawalRecipient } from "../../../WithdrawalRecipient.sol";

contract MockWithdrawalRecipient is WithdrawalRecipient(msg.sender, Authority(address(0))) {}