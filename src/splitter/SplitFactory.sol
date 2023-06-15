// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;
import {Ownable} from "solady/auth/Ownable.sol";
import {ISplitMainV2} from "../interfaces/ISplitMainV2.sol";

contract SplitFactory is Ownable {
    error IdExists(bytes32 id);

    /// @dev splitmain
    ISplitMainV2 public immutable splitMain;
    
    /// @dev split id to split implmentation address
    mapping (bytes32 => address) internal splitWalletImplementations;
    

    event NewSplitWallet(bytes32 id, address implementation);

    constructor(address splitMain_, address owner) {
        splitMain = ISplitMainV2(splitMain_);
        _initializeOwner(owner);
    }

    function addSplitWallet(
        bytes32 id,
        address implementation
    ) external onlyOwner {
        if (splitWalletImplementations[id] != address(0)) {
            revert IdExists(id);
        }
        splitWalletImplementations[id] = implementation;
        emit NewSplitWallet(id, implementation);
    }

    function createSplit(
        bytes32 splitId,
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee,
        address distributor,
        address controller
    ) external returns (address split) {
        address splitWalletImplementation = splitWalletImplementations[splitId];
        split = splitMain.createSplit(
            splitWalletImplementation,
            accounts,
            percentAllocations,
            distributorFee,
            controller,
            distributor
        );
    }

    /** @notice Predicts the address for an immutable split created with recipients `accounts` with ownerships `percentAllocations` and a keeper fee for splitting of `distributorFee`
    *  @param accounts Ordered, unique list of addresses with ownership in the split
    *  @param percentAllocations Percent allocations associated with each address
    *  @param distributorFee Keeper fee paid by split to cover gas costs of distribution
    *  @return split Predicted address of such an immutable split
    */
    function predictImmutableSplitAddress(
        bytes32 splitId,
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee
    )
        external
        view
        returns (address split)
    {
        address splitWalletImplementation = splitWalletImplementations[splitId];
        split = splitMain.predictImmutableSplitAddress(
            splitWalletImplementation,
            accounts,
            percentAllocations,
            distributorFee
        );
    }
}