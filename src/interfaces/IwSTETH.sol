// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IwSTETH {
    function wrap(uint256 _stETHAmount) external returns (uint256);
}