// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
// import {ICollateral} from "collateral/interfaces/ICollateral.sol";
import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";
import {SymPodStorageV1} from "src/symbiotic/SymPodStorageV1.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import { ISymPodConfigurator } from "src/interfaces/ISymPodConfigurator.sol";
import {IETH2DepositContract} from "src/interfaces/IETH2DepositContract.sol";


/// @title SymPod
/// @author Obol
/// @notice A native restaking vault for Symbiotic
contract SymPod is SymPodStorageV1 {
    using BeaconChainProofs for bytes32[];
    using SafeTransferLib for address;
    using SafeTransferLib for ERC20;

    /// @dev gwei to wei
    uint256 public constant GWEI_TO_WEI = 1 gwei;

    /// @dev ERC4788 oracle
    address public constant BEACON_ROOTS_ORACLE_ADDRESS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;

    /// @notice Length of the EIP-4788 beacon block root ring buffer
    uint256 internal constant BEACON_ROOTS_HISTORY_BUFFER_LENGTH = 8191;

    /// @dev address used as ETH token
    address public constant ETH_ADDRESS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;

    /// @dev ETH2 deposit contract
    IETH2DepositContract public immutable ETH2_DEPOSIT_CONTRACT;

    /// @dev Withdrawal delay
    uint256 public immutable WITHDRAW_DELAY_PERIOD;

    /// @dev SymPod Configurator
    ISymPodConfigurator public immutable symPodConfigurator;

    constructor(
        ISymPodConfigurator _configurator,
        address _eth2DepositContract,
        uint256 _withdrawDelayPeriod
    ) {
        symPodConfigurator = _configurator;
        ETH2_DEPOSIT_CONTRACT = IETH2DepositContract(_eth2DepositContract);
        WITHDRAW_DELAY_PERIOD = _withdrawDelayPeriod;
    }

    /// @notice payable fallback function that receives ether deposited to the contract
    receive() external payable {
        emit NonBeaconChainETHDeposited(msg.value);
    }

    /// @notice Initialize addresses important to the SymPod functionality.
    /// Called on deployment by the SymPodFactory
    /// @param _admin Used to perform admin tasks
    /// @param _withdrawalAddress Address that receives ETH withdrawals
    /// @param _recoveryRecipient Address that receives any deposited token
    /// @dev This is called only once by the SymPodFactory
    function initialize(
        address _admin,
        address _withdrawalAddress,
        address _recoveryRecipient
    ) external initializer {
        if (_admin == address(0)) revert SymPod__InvalidAdmin();
        if (_withdrawalAddress == address(0)) revert SymPod__InvalidAddress();
        if (_recoveryRecipient == address(0)) revert SymPod__InvalidAddress();

        admin = _admin;
        withdrawalAddress = _withdrawalAddress;
        recoveryAddress = _recoveryRecipient;

        emit Initialized(address(this), _admin, _withdrawalAddress, _recoveryRecipient);
    }

    /// @notice Create new validators
    /// @param pubkey validator public keys
    /// @param signature deposit validator signatures
    /// @param depositDataRoot deposit validator data roots
    function stake(
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot
    ) external payable override {
        ETH2_DEPOSIT_CONTRACT.deposit{value: msg.value}(
            pubkey,
            symPodWithdrawalCredentials(), 
            signature,
            depositDataRoot
        );
    }
    
    /// @dev Create a checkpoint used to prove this SymPod's active validator set. Checkpoints are completed
    /// by submitting multiple active validator checkpoint proof. During the checkpoint process, the total
    /// change in ACTIVE validator balance is tracked, and any validators with 0 balance are marked `WITHDRAWN`.
    /// @dev Once finalized, the SymPod owner is awarded shares corresponding to:
    /// - the total change in their ACTIVE validator balances
    /// - any ETH balance not already awarded shares
    /// @dev A checkpoint cannot be created if the pod already has an outstanding checkpoint. If
    /// this is the case, the pod owner MUST complete the existing checkpoint before starting a new one.
    /// @param revertIfNoBalance Forces a revert if the pod ETH balance is 0. This allows the pod owner
    /// to prevent accidentally starting a checkpoint that will not increase their shares
    function startCheckpoint(
        bool revertIfNoBalance
    )
        external
        onlyAdmin
    {
        _startCheckpoint(revertIfNoBalance);
    }
    
    /// @dev Advance the current checkpoint towards completion by submitting one or more validator
    /// checkpoint proofs. Anyone can call this method to submit proofs towards the current checkpoint.
    /// For each validator proven, the current checkpoint's `proofsRemaining` decreases.
    /// @dev If the checkpoint's `proofsRemaining` reaches 0, the checkpoint is finalized.
    /// (see `_updateCheckpoint` for more details)
    /// @dev This method can only be called when there is a currently-active checkpoint.
    /// @param balanceContainerProof proves the beacon's current balance container root against a checkpoint's `beaconBlockRoot`
    /// @param validatorBalancesProof proves the validator balances against the balance container root
    function verifyBalanceCheckPointProofs(
        BeaconChainProofs.BalanceContainerProof calldata balanceContainerProof,
        BeaconChainProofs.BalanceProof calldata validatorBalancesProof
    ) external {
        Checkpoint memory activeCheckpoint = currentCheckPoint;
        uint256 currentCheckpointTimestamp = activeCheckpoint.currentTimestamp;
        if (currentCheckpointTimestamp == 0) revert SymPod__InvalidCheckPointTimestamp();

        // verify the balance container proof
        BeaconChainProofs.verifyBalanceRootAgainstBlockRoot({
            beaconBlockRoot: activeCheckpoint.beaconBlockRoot,
            proof: balanceContainerProof
        });

        // verify the passed in proof
        uint256[] memory validatorBalances = BeaconChainProofs.verifyValidatorsBalance({
            balanceListRoot: balanceContainerProof.balanceListRoot,
            proof: validatorBalancesProof.proof,
            validatorIndices:validatorBalancesProof.validatorIndices,
            validatorBalances: validatorBalancesProof.validatorBalances
        });

        // process the proof
        uint256 i = 0;
        uint256 exitedBalancesGwei = 0;
        uint256 size = validatorBalancesProof.validatorIndices.length;

        for (i; i < size;) {
            // check it's a active validator
            uint256 currentValidatorIndex = validatorBalancesProof.validatorIndices[i];
            Validator memory currentValidatorInfo = validatorInfo[currentValidatorIndex];

            /// Check if the validator isn't in an active and skip
            if (currentValidatorInfo.status != VALIDATOR_STATUS.ACTIVE) {
                continue;
            }
            // check if the validator has been checkpointed 
            if (currentValidatorInfo.lastCheckpointedAt >= activeCheckpoint.currentTimestamp) {
                continue;
            }

            uint64 prevValidatorBalanceGwei = currentValidatorInfo.restakedBalanceGwei;
            uint64 newValidatorBalanceGwei = uint64(validatorBalances[i]);
            
            int256 balanceDeltaGwei = 0;
            if (prevValidatorBalanceGwei != newValidatorBalanceGwei) {
                balanceDeltaGwei = int256(uint256(newValidatorBalanceGwei)) - int256(uint256(prevValidatorBalanceGwei));
                emit ValidatorBalanceUpdated(
                    currentValidatorIndex, 
                    activeCheckpoint.currentTimestamp,
                    prevValidatorBalanceGwei,
                    newValidatorBalanceGwei
                );
            }

            // Update validator info memory
            currentValidatorInfo.restakedBalanceGwei = newValidatorBalanceGwei;
            currentValidatorInfo.lastCheckpointedAt = currentCheckPointTimestamp;
            if (newValidatorBalanceGwei == 0) {
                currentValidatorInfo.status = VALIDATOR_STATUS.WITHDRAWN;
                exitedBalancesGwei += uint64(uint128(-balanceDeltaGwei));
            }

            // Update checkpoint info memory
            activeCheckpoint.proofsRemaining--;
            activeCheckpoint.balanceDeltasGwei += int128(balanceDeltaGwei);

            // Write to Storage
            if (newValidatorBalanceGwei == 0) numberOfActiveValidators--;
            validatorInfo[currentValidatorIndex] = currentValidatorInfo;

            emit ValidatorCheckpointUpdate(currentCheckpointTimestamp, currentValidatorIndex);

            unchecked {
                i += 1;
            }
        }

        // Write to Storage
        checkpointBalanceExitedGwei[uint64(currentCheckpointTimestamp)] += uint64(exitedBalancesGwei);

        _updateCheckpoint(activeCheckpoint);
    }

    /// @dev Staleness conditions
    ///  - Validator's last checkpoint is older than `beaconTimestamp`
    ///  - Validator must be `Acitve` status on the SymPod
    ///  - Validator MUST be slashed on the beacon chain
    function verifyStaleBalance(
        uint64 beaconTimestamp,
        BeaconChainProofs.ValidatorListContainerProof calldata validatorListRootProof,
        BeaconChainProofs.ValidatorProof calldata validatorFieldsProof
    ) external {
        uint256 validatorIndex = uint256(validatorFieldsProof.validatorIndices[0]);
        Validator memory validatorInfo = validatorInfo[uint256(validatorIndex)];

        if (validatorInfo.lastCheckpointedAt > beaconTimestamp) {
            revert SymPod__InvalidBeaconTimestamp();
        }

        if (validatorInfo.status != VALIDATOR_STATUS.ACTIVE) {
            revert SymPod__InvalidValidatorState();
        }
        
        // validator must be slashed to mark stale
        if (validatorFieldsProof.validatorFields[0].isValidatorSlashed() == false) {
            revert SymPod__ValidatorNotSlashed();
        }

        // verify list root
        BeaconChainProofs.verifyValidatorListRootAgainstBlockRoot({
            blockRoot: getParentBeaconBlockRoot(beaconTimestamp),
            validatorListRoot: validatorListRootProof.validatorListRoot,
            proof: validatorListRootProof.proof
        });

        // verify validator fiels against validator list root
        BeaconChainProofs.verifyValidatorFields({
            validatorListRoot: validatorListRootProof.validatorListRoot,
            validatorFields: validatorFieldsProof.validatorFields,
            proof: validatorFieldsProof.proof,
            validatorIndices: validatorFieldsProof.validatorIndices
        });

        // start checkpoint 
        _startCheckpoint(false);
    }

    /// @dev Initiate withdrawal from the SymPod
    /// @param amountOfShares amount of shares to withdraw
    /// @param nonce to use to generate the withdrawal key
    function startWithdraw(uint256 amountOfShares, uint256 nonce) external onlyAdmin returns (bytes32 withdrawalKey) {
        uint256 weiAmount = convertToAssets(amountOfShares);

        withdrawalKey = _getWithdrawalKey(weiAmount, nonce);

        uint256 withdrawalTimestamp = block.timestamp + WITHDRAW_DELAY_PERIOD;

        withdrawalQueue[withdrawalKey] = WithdrawalInfo(withdrawalAddress, uint128(weiAmount), uint128(withdrawalTimestamp));

        emit WithdrawalInitiated(withdrawalKey, weiAmount, withdrawalTimestamp);
    }

    /// @dev Finalize withdrawal
    /// @param withdrawalKey Generated withdrawal key
    /// @param acceptLowerThan configuration to accept withdrawal lower than the weiAmount
    function finishWithdraw(bytes32 withdrawalKey, bool acceptLowerThan) external {

        WithdrawalInfo memory withdrawalInfo = withdrawalQueue[withdrawalKey];

        address withdrawAddress = withdrawalInfo.to;
        if (withdrawAddress == address(0)) revert SymPod__InvalidWithdrawalKey();
        if (withdrawalInfo.timestamp > block.timestamp) revert SymPod__WithdrawDelayPeriod();
        if (withdrawalInfo.weiAmount > address(this).balance && acceptLowerThan == false) revert SymPod__InsufficientBalance();
        
        uint256 amountToTransfer = address(this).balance >= withdrawalInfo.weiAmount ? withdrawalInfo.weiAmount : address(this).balance;
        
        // Write to Storage
        delete withdrawalQueue[withdrawalKey];
        
        // update the available execution layer eth
        withdrawableRestakedExecutionLayerGwei -= uint64 (amountToTransfer / GWEI_TO_WEI);

        // Interactions

        emit WithdrawalFinalized(withdrawalKey, amountToTransfer, withdrawalInfo.weiAmount);

        withdrawAddress.safeTransferETH(amountToTransfer);
    }

    /// @notice Slash callback for burning collateral.
    /// @dev A slashing does not incur 
    /// @param slashedShares amount of shares to slash
    /// @param captureTimestamp time point when the stake was captured
    /// @dev Only the slasher can call this function.
    function onSlash(uint256 slashedShares, uint48 captureTimestamp) external nonReentrant returns (bytes32 withdrawalKey) {
        if (msg.sender != slasher) {
            revert SymPod__NotSlasher();
        }
        
        uint256 assets = convertToAssets(slashedShares);

        _burn(msg.sender, slashedShares);

        withdrawalKey = _getWithdrawalKey(assets, captureTimestamp);
        
        withdrawalQueue[withdrawalKey] = WithdrawalInfo(msg.sender, uint128(assets), uint128(block.timestamp));

        emit WithdrawalInitiated(withdrawalKey, assets, captureTimestamp);
    }

    /// @notice Verify a multiple validator withdrawal credentials
    /// @param beaconTimestamp timestamp for beacon block oracle root
    /// @param validatorListRoot merkle root of the validator list container
    /// @param validatorListRootProof proof for 
    function verifyValidatorWithdrawalCredentials(
        uint64 beaconTimestamp,
        bytes32 validatorListRoot,
        bytes32[] calldata validatorListRootProof,
        BeaconChainProofs.ValidatorProof calldata validatorProof
    ) external {
        
        // Verify passed-in `validatorListRoot` against the beacon block root
        BeaconChainProofs.verifyValidatorListRootAgainstBlockRoot({
            blockRoot: getParentBeaconBlockRoot(beaconTimestamp),
            validatorListRoot: validatorListRoot,
            proof: validatorListRootProof
        });

        uint256 totalAmountToBeRestakedWei = _verifyWithdrawalCredentials(
            validatorListRoot,
            validatorProof
        );

        _increaseBalance(admin, totalAmountToBeRestakedWei);
    }

    /// @notice called by owner of a pod to remove any ERC20s deposited in the pod
    function recoverTokens(
        ERC20[] memory tokenList,
        uint256[] memory amountsToWithdraw,
        address recipient
    ) external onlyAdmin {
        if (tokenList.length != amountsToWithdraw.length) {
            revert SymPod__InvalidTokenAndAmountSize();
        }

        for (uint256 i = 0; i < tokenList.length; i++) {
            tokenList[i].safeTransfer(recipient, amountsToWithdraw[i]);
        }
    }

    /// @dev total amount of underlying asset
    function totalAssets() public view override returns (uint256 assets) {
        assets = totalRestakedETH;
    }

    /// @dev defines asset addresss
    function asset() public view override returns (address) {
        return ETH_ADDRESS;
    }

    /// @dev decimals
    function decimals() public view override returns (uint8) {
        return 18;
    }

    /// @dev name
    function name() public view override returns (string memory) {
        return "";
    }


    /// @notice symbol 
    function symbol() public view override returns (string memory) {
        return "";
    }

    /// @notice Returns a SymPod withdrawal credentials
    function symPodWithdrawalCredentials() public view override returns (bytes memory cred) {
        cred = abi.encodePacked(bytes1(uint8(1)), bytes11(0), address(this));
    }

    /// @notice Fetch the parent block root of the slot with the given `timestamp` from the 4788 oracle 
    /// @param timestamp of the block for which the parent block root will be returned. MUST correspond
    /// to an existing slot within the last 24 hours. If the slot at `timestamp` was skipped, this method
    /// will revert.
    function getParentBeaconBlockRoot(uint64 timestamp) public view returns (bytes32) {
        if ((block.timestamp - timestamp) > (BEACON_ROOTS_HISTORY_BUFFER_LENGTH * 12)) {
            revert SymPod__TimestampOutOfRange();
        }

        (bool success, bytes memory result) = BEACON_ROOTS_ORACLE_ADDRESS.staticcall(abi.encode(timestamp));
        if (!success && result.length > 0) revert SymPod__InvalidBlockRoot();
        return abi.decode(result, (bytes32));
    }

    /// @dev Generate withdrawal key
    function _getWithdrawalKey(uint256 weiAmount, uint256 nonce) internal returns (bytes32 withdrawalKey) {
        withdrawalKey = keccak256(abi.encode(msg.sender, weiAmount, block.timestamp, nonce));
    }

    /// @notice Verify withdrawal credentials
    function _verifyWithdrawalCredentials(
        bytes32 validatorListRoot,
        BeaconChainProofs.ValidatorProof calldata validatorData
    ) internal returns (uint256 totalAmountToBeRestakedWei) {
        // verify the passed validator multi proof
        BeaconChainProofs.verifyValidatorFields({
            validatorListRoot: validatorListRoot,
            validatorFields:  validatorData.validatorFields,
            proof: validatorData.proof,
            validatorIndices: validatorData.validatorIndices
        });


        uint256 size = validatorData.validatorFields.length;
        uint256 restakedBalanceGwei = 0;
        
        uint64 lastCheckpointedAt = currentCheckPointTimestamp == 0 ? lastCheckpointTimestamp : currentCheckPointTimestamp;

        for (uint256 i; i < size;) {
            uint256 validatorIndex = validatorData.validatorIndices[i];
            bytes32 pubkeyHash = validatorData.validatorFields[i].getPubkeyHash();

            Validator memory currentValidatorInfo = validatorInfo[validatorIndex];
            if (currentValidatorInfo.status != VALIDATOR_STATUS.INACTIVE) revert SymPod__InvalidValidatorState();

            uint64 exitEpoch = validatorData.validatorFields[i].getExitEpoch();
            if (exitEpoch != BeaconChainProofs.FAR_FUTURE_EPOCH) revert SymPod__InvalidValidatorExitEpoch();
            
            uint64 activationEpoch = validatorData.validatorFields[i].getActivationEpoch();
            if (activationEpoch == BeaconChainProofs.FAR_FUTURE_EPOCH) revert SymPod__InvalidValidatorActivationEpoch();

            bytes32 withdrawalCredentials = validatorData.validatorFields[i].getWithdrawalCredentials();
            if (withdrawalCredentials != bytes32(symPodWithdrawalCredentials())) revert SymPod__InvalidValidatorWithdrawalCredentials();
            
            restakedBalanceGwei += validatorData.validatorFields[i].getEffectiveBalanceGwei();

            // Emit events
            emit ValidatorRestaked(validatorIndex, restakedBalanceGwei, lastCheckpointedAt);


            // Write to Storage
            validatorInfo[validatorIndex] = Validator({
                restakedBalanceGwei: uint64(restakedBalanceGwei),
                lastCheckpointedAt: uint64(lastCheckpointedAt),
                status: VALIDATOR_STATUS.ACTIVE
            });

            unchecked {
                i++;
            }
        }

        totalAmountToBeRestakedWei = restakedBalanceGwei * GWEI_TO_WEI;

        // Account for validator in future checkpoints. Note that if this pod has never started a
        // checkpoint before, `lastCheckpointedAt` will be zero here. This is fine because the main
        // purpose of `lastCheckpointedAt` is to enforce that newly-verified validators are not
        // eligible to progress already-existing checkpoints - however in this case, no checkpoints exist.
       
        // Write to storage
        numberOfActiveValidators += uint64(size);

    }

    /// @notice increase balance
    /// @param to address to increase balance
    /// @param assets amount of assets to credit
    function _increaseBalance(address to, uint256 assets) internal {
        if ((assets + totalAssets()) > maxDeposit(to)) revert DepositMoreThanMax();
        
        uint256 shares = convertToShares(assets);

        // Write to storage
        _mint(to, shares);
        totalRestakedETH += assets;

        emit IncreasedBalance(totalRestakedETH, shares);
    }

    
    /// @dev Initiate a checkpoint proof by snapshotting both the SymPod ETH balance and the
    /// current block's parent block root. After providing a checkpoint proof for each of the
    /// pod's ACTIVE validators, the pod's ETH balance is awarded shares and can be withdrawn.
    /// @dev ACTIVE validators are validators with verified withdrawal credentials (See
    /// `verifyWithdrawalCredentials` for details)
    /// @dev If the pod does not have any ACTIVE validators, the checkpoint is automatically
    /// finalized.
    /// @dev Once started, a checkpoint MUST be completed! It is not possible to start a
    /// checkpoint if the existing one is incomplete.
    /// @param revertIfNoBalance If the available ETH balance for checkpointing is 0 and this is
    /// true, this method will revert
    function _startCheckpoint(bool revertIfNoBalance) internal {
        // Verify that checkpoint isn't paused
        if (symPodConfigurator.isCheckPointPaused() == true) revert SymPod__CheckPointPaused();
        // check that there is no ongoing checkpoints
        if (currentCheckPointTimestamp != 0) revert SymPod__CompletePreviousCheckPoint();

        // prevent checkpoint from being start twice in a block
        if (lastCheckpointTimestamp != uint64(block.timestamp)) revert SymPod__CannotActivateCheckPoint();

        // fetch the pod balance minus already accounted balance
        uint64 podBalanceGwei = uint64(address(this).balance / GWEI_TO_WEI) - withdrawableRestakedExecutionLayerGwei;

        // If the caller doesn't want a "0 balance" checkpoint, revert
        if (revertIfNoBalance && podBalanceGwei == 0) {
            revert SymPod__RevertIfNoBalance();
        }
        
        Checkpoint memory checkpoint = Checkpoint({
            beaconBlockRoot: getParentBeaconBlockRoot(uint64(block.timestamp)),
            proofsRemaining: uint24(numberOfActiveValidators),
            podBalanceGwei: podBalanceGwei,
            currentTimestamp: uint40(block.timestamp),
            balanceDeltasGwei: 0
        });

        // Write to Storage
        currentCheckPointTimestamp = uint64(block.timestamp);

        _updateCheckpoint(checkpoint);


        emit CheckpointCreated(uint64(block.timestamp), checkpoint.beaconBlockRoot, checkpoint.proofsRemaining);
    }

    function _updateCheckpoint(Checkpoint memory checkpoint) internal {
        if (checkpoint.proofsRemaining == 0) {
            int256 totalShareDeltaWei =
                (int128(uint128(checkpoint.podBalanceGwei)) + checkpoint.balanceDeltasGwei) * int256(GWEI_TO_WEI);

            // Write to Storage
            withdrawableRestakedExecutionLayerGwei += checkpoint.podBalanceGwei;
             // Finalize the checkpoint
            lastCheckpointTimestamp = currentCheckPointTimestamp;

            delete currentCheckPointTimestamp;
            delete currentCheckPoint;

            totalRestakedETH += uint256(checkpoint.balanceDeltasGwei);

            emit CheckpointFinalized(lastCheckpointTimestamp, totalShareDeltaWei);

        } else {
            currentCheckPoint = checkpoint;
        }
    }

    function deposit(uint256, address) public pure override returns (uint256) {
        revert SymPod__NotImplemented();
    }

    function mint(uint256, address) public pure override returns (uint256) {
        revert SymPod__NotImplemented();
    }

    /// @inheritdoc SymPodStorageV1
    function withdraw(uint256, address, address) public pure override returns (uint256) {
        revert SymPod__NotImplemented();
    }

    /// @inheritdoc SymPodStorageV1
    function redeem(uint256, address, address) public pure override returns (uint256) {
        revert SymPod__NotImplemented();
    }

    /// @inheritdoc SymPodStorageV1
    function previewDeposit(uint256) public pure override returns (uint256) {
        revert SymPod__NotImplemented();
    }
    
    /// @inheritdoc SymPodStorageV1
    function previewRedeem(uint256) public pure override returns (uint256) {
        revert SymPod__NotImplemented();
    }

}