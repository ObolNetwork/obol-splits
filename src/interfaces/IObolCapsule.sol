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
    error Invalid_Balance();
    error Invalid_ValidatorPubkey(bytes32 validatorPubkeyHash);

    event Initialized(address owner);

    /// @dev Emitted on stake
    event ObolPodStaked(bytes32 pubkeyHash, uint256 amount);

    /// @notice Emitted on recoverFunds()
    /// @param token token address
    event RecoverFunds(address token, address recoveryAddress, uint256 amount);

    /// @notice Emitted on distributeRewards
    event DistributeFunds(
        uint256 principal,
        uint256 rewards,
        uint256 fee
    );
    
    event ValidatorExit(
        uint256 oracleTimestamp,
        uint256 totalExitedBalance,
        uint256 mostRecentExitEpoch
    );


    function stake(
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot
    ) external payable;
}