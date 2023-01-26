// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

struct SplitConfiguration {
    address[] accounts;
    uint32[] percentAllocations;
    uint32 distributorFee;
    address controller;
}

interface ISplitMain {
    /// @notice Creates a new split with recipients `accounts` with ownerships `percentAllocations`, a keeper fee for splitting of `distributorFee` and the controlling address `controller`
    /// @param accounts Ordered, unique list of addresses with ownership in the split
    /// @param percentAllocations Percent allocations associated with each address
    /// @param distributorFee Keeper fee paid by split to cover gas costs of distribution
    /// @param controller Controlling address (0x0 if immutable)
    /// @return split Address of newly created split
    function createSplit(
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee,
        address controller
    ) external returns (address);
}
