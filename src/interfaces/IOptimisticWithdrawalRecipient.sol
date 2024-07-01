// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IOptimisticPullWithdrawalRecipient.sol";

interface IOptimisticWithdrawalRecipient is IOptimisticPullWithdrawalRecipient{
    function distributeFundsPull() external payable;
}