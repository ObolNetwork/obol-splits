// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

/**
 * @title IDistributedValidatorDepositor
 * @notice Interface for the Distributed Validator Depositor contract that handles group deposits
 */
interface IDistributedValidatorDepositor {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------
    
    /// @notice Emitted when an operator makes a deposit
    /// @param operator The address of the operator making the deposit
    /// @param amount The amount of ETH deposited
    event OperatorDeposit(address indexed operator, uint256 amount);
    
    /// @notice Emitted when the contract is initialized with validator count and operators
    /// @param validatorCount Number of validators this contract will fund
    /// @param operators Array of operator addresses
    /// @param shares Array of operator shares (must sum to 100)
    event DepositorInitialized(uint256 validatorCount, address[] operators, uint256[] shares);
    
    /// @notice Emitted when deposits are complete and funds are sent to beacon chain
    /// @param validatorCount Number of validators funded
    /// @param totalAmount Total amount sent to beacon chain
    event DepositComplete(uint256 validatorCount, uint256 totalAmount);

    /// @notice Emitted when validator keys are set
    /// @param validatorIndex Index of the validator
    /// @param pubkey The validator's public key
    event ValidatorKeysSet(uint256 indexed validatorIndex, bytes pubkey);

    /// @notice Emitted when a deposit is made to the beacon chain
    /// @param validatorIndex Index of the validator
    /// @param pubkey The validator's public key
    /// @param withdrawalCredentials The withdrawal credentials
    /// @param amount The amount deposited
    event BeaconDeposit(
        uint256 indexed validatorIndex,
        bytes pubkey,
        bytes withdrawalCredentials,
        uint256 amount
    );

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------
    
    /// @notice Thrown when deposit amount is not a whole number of ETH
    error InvalidDepositAmount();
    
    /// @notice Thrown when total deposits would exceed target
    error DepositLimitExceeded();
    
    /// @notice Thrown when operators array length doesn't match shares array length
    error ArrayLengthMismatch();
    
    /// @notice Thrown when shares don't sum to 100
    error InvalidShares();
    
    /// @notice Thrown when trying to deposit after target is reached
    error DepositsCompleted();

    /// @notice Thrown when validator keys are invalid
    error InvalidValidatorKeys();

    /// @notice Thrown when beacon deposit fails
    error BeaconDepositFailed();

    /// -----------------------------------------------------------------------
    /// Functions
    /// -----------------------------------------------------------------------
    
    /**
     * @notice Initialize the depositor with validator count and operator details
     * @param validatorCount Number of validators this contract will fund
     * @param operators Array of operator addresses
     * @param shares Array of operator shares (must sum to 100)
     */
    function initialize(
        uint256 validatorCount,
        address[] calldata operators,
        uint256[] calldata shares
    ) external;

    /**
     * @notice Set validator keys for beacon chain deposit
     * @param validatorIndex Index of the validator
     * @param pubkey The validator's public key
     * @param signature The validator's signature
     * @param depositDataRoot The deposit data root
     */
    function setValidatorKeys(
        uint256 validatorIndex,
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot
    ) external;

    /**
     * @notice Set withdrawal credentials for all validators
     * @param withdrawalCredentials The withdrawal credentials to use
     */
    function setWithdrawalCredentials(bytes calldata withdrawalCredentials) external;

    /**
     * @notice Trigger deposits to the beacon chain for completed validators
     * @dev Can only be called when deposits are complete
     */
    function submitDeposits() external;

    /**
     * @notice Deposit ETH to the contract
     * @dev Must be whole ETH units, no decimals
     */
    function deposit() external payable;

    /**
     * @notice Get the target amount needed (32 ETH * validator count)
     * @return uint256 Target amount in wei
     */
    function getTargetAmount() external view returns (uint256);

    /**
     * @notice Get the remaining amount needed to reach target
     * @return uint256 Remaining amount in wei
     */
    function getRemainingAmount() external view returns (uint256);

    /**
     * @notice Get operator's share of deposits
     * @param operator Address of the operator
     * @return uint256 Operator's share (0-100)
     */
    function getOperatorShare(address operator) external view returns (uint256);

    /**
     * @notice Check if deposits are complete
     * @return bool True if target amount has been reached
     */
    function isComplete() external view returns (bool);
}
