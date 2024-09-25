// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ISymPod {

    enum VALIDATOR_STATUS {
        INACTIVE, // doesnt exist
        ACTIVE, // staked on ethpos and withdrawal credentials are pointed to the EigenPod
        WITHDRAWN // withdrawn from the Beacon Chain
    }

    /// @notice Info for withdrawal requests
    struct WithdrawalInfo {
        // receiver address
        address to;
        // amount to transfer
        uint128 weiAmount;
        // timestamp the withdrawal becomses valid
        uint128 timestamp;
    }

    struct Validator {
        // index of the validator in the beacon chain
        // uint64 validatorIndex;
        // amount of beacon chain ETH restaked on EigenLayer in gwei
        uint64 restakedBalanceGwei;
        //timestamp of the validator's most recent balance update
        uint64 lastCheckpointedAt;
        // status of the validator
        VALIDATOR_STATUS status;
    }

    struct Checkpoint {
        bytes32 beaconBlockRoot;
        uint24 proofsRemaining;
        uint64 podBalanceGwei;
        uint40 currentTimestamp;
        int128 balanceDeltasGwei;
    }

    /// @dev invalid addresss
    error SymPod__InvalidAddress();

    /// @dev Invalid admin addresss
    error SymPod__InvalidAdmin();

    /// @dev unauthorized access
    error SymPod__Unauthorized();

    /// @notice Returns on non-implementation
    error SymPod__NotImplemented();

    error SymPod__InvalidTokenAndAmountSize();

    error SymPod__InvalidCheckPointTimestamp();

    ///@dev Returns on invalid beacon timestamp
    error SymPod__InvalidBeaconTimestamp();

    error SymPod__InvalidValidatorState();

    error SymPod__ValidatorNotSlashed();

    error SymPod__TimestampOutOfRange();

    error SymPod__InvalidBlockRoot();

    error SymPod__InvalidWithdrawalAmount();

    error SymPod__InvalidWithdrawalKey();

    error SymPod__WithdrawDelayPeriod();

    error SymPod__InsufficientBalance();
    error SymPod__NotSlasher();
    error SymPod__InvalidValidatorExitEpoch();
    error SymPod__InvalidValidatorActivationEpoch();
    error SymPod__InvalidValidatorWithdrawalCredentials();
    error SymPod__CheckPointPaused();
    error SymPod__CompletePreviousCheckPoint();
    error SymPod__CannotActivateCheckPoint();
    error SymPod__RevertIfNoBalance();



    /// @dev Emitted on stake on SymPod
    event SymPodStaked(
        bytes32 pubKeyHash,
        uint256 value
    );

    event NonBeaconChainETHDeposited(
        uint256 amount
    );

    event Initialized(address indexed pod, address admin, address withdrawalAddress, address recoveryRecipient);

    event CheckpointCreated(
        uint256 timestamp,
        bytes32 beaconBlockRoot,
        uint256 proofsRemaining
    );

    event ValidatorBalanceUpdated(
        uint256 currentValidatorIndex, 
        uint256 currentTimestamp,
        uint256 oldValidatorBalanceGwei,
        uint256 newValidatorBalanceGwei
    );

    event ValidatorCheckpointUpdate(
        uint256 checkpointTimestamp,
        uint256 validatorIndex
    );

    event WithdrawalInitiated(
        bytes32 withdrawalkey,
        uint256 amount,
        uint256 withdrawalTimestamp
    );

    event WithdrawalFinalized(
        bytes32 withdrawalKey,
        uint256 actualAmountWithdrawn,
        uint256 expectedAmountToWithdraw
    );

    event ValidatorRestaked(
        uint256 validatorIndex,
        uint256 restakedBalanceGwei,
        uint256 lastCheckpointedAt
    );

    event IncreasedBalance(uint256 totalRestakedEth, uint256 shares);
    event CheckpointFinalized(uint256 lastCheckpointTimestamp, uint256 totalShareDeltaWei);

    function symPodWithdrawalCredentials() external view returns (bytes memory);

    function stake(
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot
    ) external payable;

}