// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "../base/BaseSplit.sol";
import "../interfaces/IValidatorWithdrawalSplit.sol";

/**
 * @title ValidatorWithdrawalSplit
 * @notice Contract for splitting validator withdrawals among operators
 */
contract ValidatorWithdrawalSplit is BaseSplit, IValidatorWithdrawalSplit {
    /// -----------------------------------------------------------------------
    /// Constants
    /// -----------------------------------------------------------------------
    
    /// @notice Scale for percentages (100%)
    uint256 public constant PERCENTAGE_SCALE = 1e5;

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------
    
    /// @notice Mapping of operator address to their share (0-100%)
    mapping(address => uint256) public operatorShares;
    
    /// @notice Array of operator addresses
    address[] public operators;

    /// @notice Whether contract has been initialized
    bool public initialized;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------
    
    constructor(address _feeRecipient, uint256 _feeShare) BaseSplit(_feeRecipient, _feeShare) {
        initialized = false;
    }

    /// -----------------------------------------------------------------------
    /// External Functions
    /// -----------------------------------------------------------------------

    /**
     * @inheritdoc IValidatorWithdrawalSplit
     */
    function initialize(address[] calldata _operators, uint256[] calldata _shares) external {
        require(!initialized, "Already initialized");
        require(_operators.length > 0, "No operators");
        
        if (_operators.length != _shares.length) {
            revert ArrayLengthMismatch();
        }
        
        uint256 totalShares;
        for (uint256 i = 0; i < _operators.length; i++) {
            if (_operators[i] == address(0)) revert InvalidOperator();
            operatorShares[_operators[i]] = _shares[i];
            totalShares += _shares[i];
        }
        
        if (totalShares != PERCENTAGE_SCALE) {
            revert InvalidShares();
        }
        
        operators = _operators;
        initialized = true;
        
        emit OperatorSharesSet(_operators, _shares);
    }

    /**
     * @inheritdoc IValidatorWithdrawalSplit
     */
    function getOperatorShare(address operator) external view returns (uint256) {
        return operatorShares[operator];
    }

    /**
     * @inheritdoc IValidatorWithdrawalSplit
     */
    function getOperators() external view returns (address[] memory) {
        return operators;
    }

    /**
     * @inheritdoc IValidatorWithdrawalSplit
     */
    function getWithdrawalCredentials() external view returns (bytes32) {
        return bytes32(uint256(uint160(address(this))));
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Hook called before distributing funds
     * @return tokenAddress The token address (ETH)
     * @return amount The amount to distribute
     */
    function _beforeDistribute() internal override returns (address tokenAddress, uint256 amount) {
        require(initialized, "Not initialized");
        tokenAddress = ETH_ADDRESS;
        amount = address(this).balance;
        
        emit WithdrawalDistributed(amount, block.timestamp);
    }

    /**
     * @notice Hook called before rescuing funds
     * @param tokenAddress The token address
     */
    function _beforeRescueFunds(address tokenAddress) internal override {
        require(initialized, "Not initialized");
        require(tokenAddress != ETH_ADDRESS, "Cannot rescue ETH");
    }

    /**
     * @notice Transfer ETH to each operator according to their share
     * @param amount Amount to distribute
     */
    function _distributeToOperators(uint256 amount) internal {
        uint256 remaining = amount;
        uint256 operatorCount = operators.length;
        
        for (uint256 i = 0; i < operatorCount - 1; i++) {
            address operator = operators[i];
            uint256 operatorAmount = (amount * operatorShares[operator]) / PERCENTAGE_SCALE;
            operator.safeTransferETH(operatorAmount);
            remaining -= operatorAmount;
        }
        
        // Send remaining to last operator to handle rounding
        operators[operatorCount - 1].safeTransferETH(remaining);
    }
}
