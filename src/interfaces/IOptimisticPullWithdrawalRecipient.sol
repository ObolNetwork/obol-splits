// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IOptimisticPullWithdrawalRecipient {
    function token() external view returns (address);
    function distributeFunds() external payable;
    function distributeFundsPull() external payable;
    function getTranches() external view returns (address principalRecipient, address rewardRecipient, uint256 amountOfPrincipalStake);
    function withdraw(address account, uint256 amount) external;
    function getPullBalance(address account) external view returns (uint256);
}