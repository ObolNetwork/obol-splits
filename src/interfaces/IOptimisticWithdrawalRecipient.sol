// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IOptimisticWithdrawalRecipient {
    function token() external view returns (address);
    function distributeFunds() external payable;
    function distributeFundsPull() external payable;
}