// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ISplitsWarehouse {
    function NATIVE_TOKEN() external view returns (address);

    function deposit(address receiver, address token, uint256 amount) external payable;

    function batchDeposit(address[] calldata receivers, address token, uint256[] calldata amounts) external;

    function batchTransfer(address[] calldata receivers, address token, uint256[] calldata amounts) external;

    function withdraw(address owner, address token) external;
}