// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

contract DepositContractMock {
    /// @notice Submit a Phase 0 DepositData object.
    /// Used as a protection against malformed input.
    function deposit(
        bytes calldata,
        bytes calldata,
        bytes calldata,
        bytes32
    ) external payable {
        if (msg.value > 0) {
            payable(msg.sender).transfer(msg.value); //send ether back
        }
    }
}