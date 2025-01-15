// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

/**
 * @title IValidatorWithdrawalSplit
 * @notice Interface for the validator withdrawal split contract
 */
interface IValidatorWithdrawalSplit {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------
    
    /// @notice Emitted when operator shares are set
    /// @param operators Array of operator addresses
    /// @param shares Array of operator shares
    event OperatorSharesSet(address[] operators, uint256[] shares);

    /// @notice Emitted when ETH is distributed to operators
    /// @param amount Total amount distributed
    /// @param timestamp Time of distribution
    event WithdrawalDistributed(uint256 amount, uint256 timestamp);

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------
    
    /// @notice Thrown when operators array length doesn't match shares array length
    error ArrayLengthMismatch();
    
    /// @notice Thrown when shares don't sum to 100%
    error InvalidShares();

    /// @notice Thrown when an operator address is invalid
    error InvalidOperator();

    /// -----------------------------------------------------------------------
    /// Functions
    /// -----------------------------------------------------------------------
    
    /**
     * @notice Initialize the split with operator shares
     * @param operators Array of operator addresses
     * @param shares Array of operator shares (must sum to 100%)
     */
    function initialize(address[] calldata operators, uint256[] calldata shares) external;

    /**
     * @notice Get an operator's share
     * @param operator Address of the operator
     * @return uint256 Operator's share (0-100%)
     */
    function getOperatorShare(address operator) external view returns (uint256);

    /**
     * @notice Get all operators
     * @return address[] Array of operator addresses
     */
    function getOperators() external view returns (address[] memory);

    /**
     * @notice Get withdrawal credentials for this split
     * @return bytes32 The withdrawal credentials
     */
    function getWithdrawalCredentials() external view returns (bytes32);

    /**
     * @notice Distribute ETH to operators according to their shares
     * @return uint256 Amount distributed
     */
    function distribute() external returns (uint256);
}
