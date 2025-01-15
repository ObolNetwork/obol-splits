// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "./ValidatorWithdrawalSplit.sol";
import "../base/BaseSplitFactory.sol";

/**
 * @title ValidatorWithdrawalSplitFactory
 * @notice Factory contract for deploying ValidatorWithdrawalSplit contracts
 */
contract ValidatorWithdrawalSplitFactory is BaseSplitFactory {
    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    /// @notice Fee recipient for all splits
    address public immutable feeRecipient;

    /// @notice Fee share for all splits (0-100%)
    uint256 public immutable feeShare;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------
    
    /// @notice Emitted when a new split is created
    /// @param split Address of the new split contract
    /// @param operators Array of operator addresses
    event SplitCreated(address indexed split, address[] operators);

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _feeRecipient, uint256 _feeShare) {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        require(_feeShare < 1e5, "Invalid fee share");
        feeRecipient = _feeRecipient;
        feeShare = _feeShare;
    }

    /// -----------------------------------------------------------------------
    /// External Functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Create a new ValidatorWithdrawalSplit contract
     * @param operators Array of operator addresses
     * @param shares Array of operator shares (must sum to 100%)
     * @return address Address of the new split contract
     */
    function createSplit(
        address[] calldata operators,
        uint256[] calldata shares
    ) external returns (address) {
        // Deploy new split contract
        ValidatorWithdrawalSplit split = new ValidatorWithdrawalSplit(
            feeRecipient,
            feeShare
        );
        
        // Initialize it
        split.initialize(operators, shares);
        
        emit SplitCreated(address(split), operators);
        
        return address(split);
    }

    /**
     * @notice Required override from BaseSplitFactory
     * @param token Token address (not used)
     * @param withdrawalAddress Withdrawal address (not used)
     */
    function createCollector(
        address token,
        address withdrawalAddress
    ) external pure override returns (address) {
        revert("Not implemented");
    }
}
