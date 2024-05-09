// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IObolCapsule {
    
    error InvalidAddress();
    error AlreadyInitialized();
    error InvalidStakeSize();
    error InvalidProof();
    error InvalidCallData();
    error Invalid_FeeShare(uint256 fee);
    error Invalid_FeeRecipient();
    error Invalid_Timestamp(uint256 timestamp);
    error Invalid_ProofTimestamp(uint256 withdrawalTimestamp, uint256 mostRecentTimestamp);
    error Invalid_ValidatorStatus();
    
    event Initialized(address owner);

    /// @dev Emitted on stake
    event ObolPodStaked(bytes32 pubkeyHash, uint256 amount);

    /// @notice Emitted on recoverFunds()
    /// @param token token address
    event RecoverFunds(address token, address recoveryAddress, uint256 amount);

    event Withdraw(
        bytes32 indexed validatorPubkeyHash,
        uint256 amountToSendGwei,
        uint256 oracleTimestamp,
        uint256 validatorStatus
    );


    function stake(
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot
    ) external payable;
}