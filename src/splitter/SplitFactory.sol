// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

contract SplitFactory {

    constructor(address splitMain) {
        splitMain = splitMain;
    }

    function createSplit(
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee,
        address controller
    ) {
         if (controller == address(0)) {
            // create immutable split
            split = Clones.cloneDeterministic(walletImplementation, splitHash);
        } else {
            // create mutable split
            split = Clones.clone(walletImplementation);
            splits[split].controller = controller;
        }
    }

    /** @notice Predicts the address for an immutable split created with recipients `accounts` with ownerships `percentAllocations` and a keeper fee for splitting of `distributorFee`
    *  @param accounts Ordered, unique list of addresses with ownership in the split
    *  @param percentAllocations Percent allocations associated with each address
    *  @param distributorFee Keeper fee paid by split to cover gas costs of distribution
    *  @return split Predicted address of such an immutable split
    */
    function predictImmutableSplitAddress(
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee
    )
        external
        view
        override
        returns (address split)
    {
       
    }
}