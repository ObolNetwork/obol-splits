// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "./DistributedValidatorDepositor.sol";
import "../base/BaseSplitFactory.sol";

/**
 * @title DistributedValidatorDepositorFactory
 * @notice Factory contract for deploying DistributedValidatorDepositor contracts
 */
contract DistributedValidatorDepositorFactory is BaseSplitFactory {
    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    /// @notice The beacon chain deposit contract address
    address public immutable beaconDepositAddress;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _beaconDepositAddress) {
        require(_beaconDepositAddress != address(0), "Invalid beacon deposit address");
        beaconDepositAddress = _beaconDepositAddress;
    }

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------
    
    /// @notice Emitted when a new depositor is created
    /// @param depositor Address of the new depositor contract
    /// @param validatorCount Number of validators
    /// @param operators Array of operator addresses
    event DepositorCreated(
        address indexed depositor,
        uint256 validatorCount,
        address[] operators
    );

    /// -----------------------------------------------------------------------
    /// External Functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Create a new DistributedValidatorDepositor contract
     * @param validatorCount Number of validators to fund
     * @param operators Array of operator addresses
     * @param shares Array of operator shares (must sum to 100)
     * @return address Address of the new depositor contract
     */
    function createDepositor(
        uint256 validatorCount,
        address[] calldata operators,
        uint256[] calldata shares
    ) external returns (address) {
        // Deploy new depositor contract
        DistributedValidatorDepositor depositor = new DistributedValidatorDepositor(
            beaconDepositAddress
        );
        
        // Initialize it
        depositor.initialize(validatorCount, operators, shares);
        
        emit DepositorCreated(address(depositor), validatorCount, operators);
        
        return address(depositor);
    }

    /**
     * @notice Required override from BaseSplitFactory
     * @dev Not used for this factory
     */
    function createCollector(address, address) external pure override returns (address) {
        revert("Not implemented");
    }
}
