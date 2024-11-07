// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";

interface IERC4626 {
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
}

interface ISymPod {

    enum VALIDATOR_STATE {
        INACTIVE, // doesnt exist
        ACTIVE, // staked on ethpos and withdrawal credentials are pointed to the SymPod
        WITHDRAWN // withdrawn from the Beacon Chain
    }

    /// @notice Info for withdrawal requests
    struct WithdrawalInfo {
        // address that holds the shares
        address owner;
        // receiver address
        address to;
        // amount to transfer
        uint128 amountInWei;
        // timestamp the withdrawal becomses valid
        uint128 timestamp;
    }

    struct EthValidator {
        // index of the validator in the beacon chain
        uint40 validatorIndex;
        // amount of beacon chain ETH restaked in gwei
        uint64 restakedBalanceGwei;
        // timestamp of the validator's most recent balance update
        uint64 lastCheckpointedAt;
        // status of the validator
        VALIDATOR_STATE status;
    }

    struct Checkpoint {
        bytes32 beaconBlockRoot;
        uint24 pendingProofs;
        uint64 podBalanceGwei;
        uint40 currentTimestamp;
        int128 balanceDeltasGwei;
    }

    /// @dev invalid addresss
    error SymPod__InvalidAddress();
    error SymPod__InvalidWithdrawalAddress();
    error SymPod__InvalidRecoveryAddress();

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
    error SymPod__OngoingCheckpoint();
    error SymPod__WithdrawalsPaused();
    error SymPod__AmountTooLarge();
    error SymPod__InvalidDelayPeriod();
    error SymPod__InvalidAmountOfShares();
    error SymPod__AmountInWei();
    error SymPod__WithdrawalKeyExists();
    error SymPod__InvalidTimestamp();
    error SymPod__InvalidBalanceDelta();
    error SymPod__ExceedBalance();
    error SymPod__AmountOfSharesInvalid();

    /// @dev Emitted on stake on SymPod
    event SymPodStaked(
        bytes32 pubKeyHash,
        uint256 value
    );

    event NonBeaconChainETHDeposited(
        uint256 amount
    );

    event Initialized(
        address slasher,
        address admin,
        address withdrawalAddress,
        address recoveryRecipient
    );

    event CheckpointCreated(
        uint256 timestamp,
        bytes32 beaconBlockRoot,
        uint256 pendingProofs
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

    event Slashed(
        bytes32 withdrawalkey,
        uint256 amount,
        uint256 captureTimestamp
    );

    event WithdrawalFinalized(
        bytes32 withdrawalKey,
        uint256 actualAmountWithdrawn,
        uint256 expectedAmountToWithdraw
    );

    event ValidatorRestaked(
        bytes32 validatorPubKeyHash,
        uint256 validatorIndex,
        uint256 restakedBalanceGwei,
        uint256 lastCheckpointedAt
    );

    event IncreasedBalance(uint256 totalRestakedEth, uint256 shares);
    
    event CheckpointCompleted(uint256 lastCheckpointTimestamp, int256 totalShareDeltaWei);

    function symPodWithdrawalCredentials() external view returns (bytes memory);

    function stake(
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot
    ) external payable;

    function startCheckpoint(bool revertIfNoBalance) external;

    function verifyBalanceCheckpointProofs(
        BeaconChainProofs.BalanceRegistryProof calldata balanceRegistryProof,
        BeaconChainProofs.BalancesMultiProof calldata validatorBalancesProof
    ) external;

    function verifyValidatorWithdrawalCredentials(
        uint64 beaconTimestamp,
        BeaconChainProofs.ValidatorRegistryProof calldata validatorRegistryProof,
        BeaconChainProofs.ValidatorsMultiProof calldata validatorProof
    ) external; 

    function verifyExpiredBalance(
        uint64 beaconTimestamp,
        BeaconChainProofs.ValidatorRegistryProof calldata validatorRegistryProof,
        BeaconChainProofs.ValidatorProof calldata validatorProof
    ) external;
    
    function verifyExceedBalanceDelta(
        uint64 beaconTimestamp,
        BeaconChainProofs.BalanceRegistryProof calldata balanceRegistryProof,
        BeaconChainProofs.BalanceProof calldata balanceProof
    ) external;

    function onSlash(uint256 amountWei) external returns (bytes32 withdrawalKey);

    function initWithdraw(uint256 amountInWei, uint256 nonce) external returns (bytes32 withdrawalKey);

    function completeWithdraw(bytes32 withdrawalKey)
    external 
    returns (uint256 amount);

}