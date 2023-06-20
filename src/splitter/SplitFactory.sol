// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;
import {Ownable} from "solady/auth/Ownable.sol";
import {SplitMainV2} from "./SplitMainV2.sol";


// @title SplitFactory
/// @author Obol
/// @notice SplitFactory to create splits
contract SplitFactory is Ownable {
    error IdExists(bytes32 id);
    error InvalidSplitWalletId(bytes32 id);

    /// @dev splitmain v2
    SplitMainV2 public immutable splitMain;
    
    /// @dev split wallet id to split implmentation address
    mapping (bytes32 => address) internal splitWalletImplementations;
    
    /// @dev Emitted on create new split wallet
    /// @param id split wallet id
    /// @param implementation split implementation address
    event NewSplitWallet(bytes32 id, address implementation);

    constructor(address owner) {
        splitMain = new SplitMainV2();
        _initializeOwner(owner);
    }

    /// @dev addSplitWallet 
    /// @param id split id
    /// @param implementation split implemenation
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

    /// @dev createSplit
    function createSplit(
        bytes32 splitWalletId,
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee,
        address distributor,
        address controller
    ) external returns (address split) {
        address splitWalletImplementation = splitWalletImplementations[splitWalletId];
        if (splitWalletImplementation == address(0)) {
            revert InvalidSplitWalletId(splitWalletId);
        }
        split = splitMain.createSplit(
            splitWalletImplementation,
            accounts,
            percentAllocations,
            distributorFee,
            controller,
            distributor
        );
    }

    /// @notice Predicts the address for an immutable split created with recipients `accounts` with ownerships `percentAllocations` and a keeper fee for splitting of `distributorFee`
    /// @param accounts Ordered, unique list of addresses with ownership in the split
    /// @param percentAllocations Percent allocations associated with each address
    /// @param distributorFee Keeper fee paid by split to cover gas costs of distribution
    /// @return split Predicted address of such an immutable split
    function predictImmutableSplitAddress(
        bytes32 splitWalletId,
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee
    )
        external
        view
        returns (address split)
    {
        address splitWalletImplementation = splitWalletImplementations[splitWalletId];
        split = splitMain.predictImmutableSplitAddress(
            splitWalletImplementation,
            accounts,
            percentAllocations,
            distributorFee
        );
    }
}