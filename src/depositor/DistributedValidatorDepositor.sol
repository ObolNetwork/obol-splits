// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "../interfaces/IDistributedValidatorDepositor.sol";
import "../interfaces/IBeaconDeposit.sol";
import "../interfaces/IValidatorWithdrawalSplit.sol";

/**
 * @title DistributedValidatorDepositor
 * @notice Contract for coordinating group deposits for distributed validators
 */
contract DistributedValidatorDepositor is IDistributedValidatorDepositor {
    /// -----------------------------------------------------------------------
    /// Constants
    /// -----------------------------------------------------------------------
    
    /// @notice Amount required per validator in wei (32 ETH)
    uint256 public constant VALIDATOR_DEPOSIT = 32 ether;
    
    /// @notice Total shares (100%)
    uint256 public constant TOTAL_SHARES = 100;

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------
    
    /// @notice Number of validators this contract will fund
    uint256 public validatorCount;
    
    /// @notice Target amount (validatorCount * 32 ETH)
    uint256 public targetAmount;
    
    /// @notice Mapping of operator address to their share (0-100)
    mapping(address => uint256) public operatorShares;
    
    /// @notice Array of operator addresses
    address[] public operators;

    /// @notice Mapping to track how much each operator has deposited
    mapping(address => uint256) public operatorDeposits;
    
    /// @notice Whether contract has been initialized
    bool public initialized;
    
    /// @notice Whether deposits are complete
    bool public depositsComplete;

    /// @notice The beacon chain deposit contract
    IBeaconDeposit public immutable beaconDeposit;

    /// @notice The withdrawal split contract
    IValidatorWithdrawalSplit public withdrawalSplit;

    /// @notice Withdrawal credentials for validators
    bytes public withdrawalCredentials;

    /// @notice Struct to hold validator keys
    struct ValidatorKeys {
        bytes pubkey;
        bytes signature;
        bytes32 depositDataRoot;
        bool isSet;
    }

    /// @notice Mapping of validator index to their keys
    mapping(uint256 => ValidatorKeys) public validatorKeys;

    /// @notice Number of validators with keys set
    uint256 public validatorKeysCount;

    /// @notice Whether deposits have been submitted to beacon chain
    bool public beaconDepositsSubmitted;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------
    
    constructor(address _beaconDeposit) {
        require(_beaconDeposit != address(0), "Invalid beacon deposit address");
        beaconDeposit = IBeaconDeposit(_beaconDeposit);
        initialized = false;
        depositsComplete = false;
        beaconDepositsSubmitted = false;
    }

    /// -----------------------------------------------------------------------
    /// External Functions
    /// -----------------------------------------------------------------------

    /**
     * @inheritdoc IDistributedValidatorDepositor
     */
    function initialize(
        uint256 _validatorCount,
        address[] calldata _operators,
        uint256[] calldata _shares
    ) external {
        require(!initialized, "Already initialized");
        require(_validatorCount > 0, "Invalid validator count");
        require(_operators.length > 0, "No operators");
        
        if (_operators.length != _shares.length) {
            revert ArrayLengthMismatch();
        }
        
        uint256 totalShares;
        for (uint256 i = 0; i < _operators.length; i++) {
            require(_operators[i] != address(0), "Invalid operator address");
            operatorShares[_operators[i]] = _shares[i];
            totalShares += _shares[i];
        }
        
        if (totalShares != TOTAL_SHARES) {
            revert InvalidShares();
        }
        
        validatorCount = _validatorCount;
        targetAmount = _validatorCount * VALIDATOR_DEPOSIT;
        operators = _operators;
        initialized = true;
        
        emit DepositorInitialized(_validatorCount, _operators, _shares);
    }

    /**
     * @notice Set the withdrawal split contract
     * @param _withdrawalSplit Address of the withdrawal split contract
     */
    function setWithdrawalSplit(address _withdrawalSplit) external {
        require(initialized, "Not initialized");
        require(_withdrawalSplit != address(0), "Invalid withdrawal split");
        require(address(withdrawalSplit) == address(0), "Split already set");

        withdrawalSplit = IValidatorWithdrawalSplit(_withdrawalSplit);

        // Verify split has same operators and shares
        address[] memory splitOperators = withdrawalSplit.getOperators();
        require(splitOperators.length == operators.length, "Operator count mismatch");

        for (uint256 i = 0; i < operators.length; i++) {
            require(splitOperators[i] == operators[i], "Operator mismatch");
            require(
                withdrawalSplit.getOperatorShare(operators[i]) == operatorShares[operators[i]],
                "Share mismatch"
            );
        }

        // Set withdrawal credentials to the split contract address
        withdrawalCredentials = abi.encodePacked(bytes1(0x01), bytes11(0), address(withdrawalSplit));
    }

    /**
     * @inheritdoc IDistributedValidatorDepositor
     */
    function setValidatorKeys(
        uint256 validatorIndex,
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot
    ) external {
        require(initialized, "Not initialized");
        require(validatorIndex < validatorCount, "Invalid validator index");
        require(!validatorKeys[validatorIndex].isSet, "Keys already set");
        require(pubkey.length == 48, "Invalid pubkey length");
        require(signature.length == 96, "Invalid signature length");
        require(address(withdrawalSplit) != address(0), "Withdrawal split not set");

        validatorKeys[validatorIndex] = ValidatorKeys({
            pubkey: pubkey,
            signature: signature,
            depositDataRoot: depositDataRoot,
            isSet: true
        });

        validatorKeysCount++;
        emit ValidatorKeysSet(validatorIndex, pubkey);
    }

    /**
     * @inheritdoc IDistributedValidatorDepositor
     */
    function submitDeposits() external {
        require(depositsComplete, "Deposits not complete");
        require(!beaconDepositsSubmitted, "Deposits already submitted");
        require(validatorKeysCount == validatorCount, "Not all validator keys set");
        require(withdrawalCredentials.length == 32, "Withdrawal credentials not set");

        for (uint256 i = 0; i < validatorCount; i++) {
            ValidatorKeys memory keys = validatorKeys[i];
            require(keys.isSet, "Validator keys not set");

            try beaconDeposit.deposit{value: VALIDATOR_DEPOSIT}(
                keys.pubkey,
                withdrawalCredentials,
                keys.signature,
                keys.depositDataRoot
            ) {
                emit BeaconDeposit(
                    i,
                    keys.pubkey,
                    withdrawalCredentials,
                    VALIDATOR_DEPOSIT
                );
            } catch {
                revert BeaconDepositFailed();
            }
        }

        beaconDepositsSubmitted = true;
    }

    /**
     * @inheritdoc IDistributedValidatorDepositor
     */
    function deposit() external payable {
        if (!initialized) {
            revert("Not initialized");
        }
        if (depositsComplete) {
            revert DepositsCompleted();
        }

        // Verify sender is an operator
        _verifyOperator();
        
        // Check deposit is whole ETH
        if (msg.value % 1 ether != 0) {
            revert InvalidDepositAmount();
        }
        
        // Check won't exceed target
        if (address(this).balance > targetAmount) {
            revert DepositLimitExceeded();
        }

        // Update operator's deposit amount
        operatorDeposits[msg.sender] += msg.value;

        // Check operator hasn't deposited more than their share
        uint256 operatorMaxDeposit = (targetAmount * operatorShares[msg.sender]) / TOTAL_SHARES;
        require(operatorDeposits[msg.sender] <= operatorMaxDeposit, "Exceeds operator share");
        
        emit OperatorDeposit(msg.sender, msg.value);
        
        // Check if target reached
        if (address(this).balance == targetAmount) {
            depositsComplete = true;
            emit DepositComplete(validatorCount, targetAmount);
        }
    }

    /**
     * @inheritdoc IDistributedValidatorDepositor
     */
    function getTargetAmount() external view returns (uint256) {
        return targetAmount;
    }

    /**
     * @inheritdoc IDistributedValidatorDepositor
     */
    function getRemainingAmount() external view returns (uint256) {
        return targetAmount - address(this).balance;
    }

    /**
     * @inheritdoc IDistributedValidatorDepositor
     */
    function getOperatorShare(address operator) external view returns (uint256) {
        return operatorShares[operator];
    }

    /**
     * @inheritdoc IDistributedValidatorDepositor
     */
    function isComplete() external view returns (bool) {
        return depositsComplete;
    }

    /**
     * @notice Get the amount deposited by an operator
     * @param operator Address of the operator
     * @return uint256 Amount deposited in wei
     */
    function getOperatorDeposit(address operator) external view returns (uint256) {
        return operatorDeposits[operator];
    }

    /**
     * @notice Get the maximum amount an operator can deposit based on their share
     * @param operator Address of the operator
     * @return uint256 Maximum deposit amount in wei
     */
    function getOperatorMaxDeposit(address operator) external view returns (uint256) {
        return (targetAmount * operatorShares[operator]) / TOTAL_SHARES;
    }

    /**
     * @notice Allow an operator to withdraw their deposit before validator creation
     * @dev Only callable before validator deposits are submitted to beacon chain
     */
    function withdrawDeposit() external {
        require(!beaconDepositsSubmitted, "Deposits already submitted");
        _verifyOperator();

        uint256 amount = operatorDeposits[msg.sender];
        require(amount > 0, "No deposit to withdraw");

        // Reset deposit tracking
        operatorDeposits[msg.sender] = 0;
        
        // Reset completion status if it was set
        if (depositsComplete) {
            depositsComplete = false;
        }

        // Transfer ETH back to operator
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");

        emit OperatorWithdraw(msg.sender, amount);
    }

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @notice Emitted when an operator withdraws their deposit
    /// @param operator Address of the operator
    /// @param amount Amount withdrawn
    event OperatorWithdraw(address indexed operator, uint256 amount);

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    /**
     * @dev Verify msg.sender is a registered operator
     */
    function _verifyOperator() internal view {
        bool isOperator = false;
        for (uint256 i = 0; i < operators.length; i++) {
            if (operators[i] == msg.sender) {
                isOperator = true;
                break;
            }
        }
        require(isOperator, "Not an operator");
    }
}
