// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";
import {SymPodStorageV1, ISymPod} from "src/symbiotic/SymPodStorageV1.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ISymPodConfigurator} from "src/interfaces/ISymPodConfigurator.sol";
import {IETH2DepositContract} from "src/interfaces/IETH2DepositContract.sol";

/// @title SymPod
/// @author Obol
/// @notice A native restaking vault for Symbiotic
/// @dev It enables staking native ETH on Symbiotic infrastructure
contract SymPod is SymPodStorageV1 {
  using BeaconChainProofs for bytes32[];
  using SafeTransferLib for address;
  using SafeTransferLib for ERC20;

  /// @dev gwei to wei
  uint256 public constant GWEI_TO_WEI = 1 gwei;

  /// @notice Length of the EIP-4788 beacon block root ring buffer
  uint256 internal constant BEACON_ROOTS_HISTORY_BUFFER_LENGTH = 8191;

  /// @dev address used as ETH token
  address public constant ETH_ADDRESS = 0x0000000000000000000000000000000000000000;

  /// @dev percentage resolution
  uint256 public constant PERCENTAGE = 100_000;

  /// @dev ERC4788 oracle
  /// 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02
  address public immutable BEACON_ROOTS_ORACLE_ADDRESS;

  /// @dev ETH2 deposit contract
  IETH2DepositContract public immutable ETH2_DEPOSIT_CONTRACT;

  /// @dev Withdrawal delay period in seconds
  uint256 public immutable WITHDRAW_DELAY_PERIOD_SECONDS;

  /// @notice Balance delta value
  /// @dev This is used in determining if the change in balance is enough
  /// to start a new checkpoint
  uint256 public immutable BALANCE_DELTA_PERCENT;

  /// @dev SymPod Configurator
  ISymPodConfigurator public immutable symPodConfigurator;

  constructor(
    address _symPodConfigurator,
    address _eth2DepositContract,
    address _beaconRootsOracle,
    uint256 _withdrawDelayPeriod,
    uint256 _balanceDelta
  ) {
    if (_symPodConfigurator == address(0)) revert SymPod__InvalidAddress();
    if (_eth2DepositContract == address(0)) revert SymPod__InvalidAddress();
    if (_withdrawDelayPeriod == 0) revert SymPod__InvalidDelayPeriod();

    symPodConfigurator = ISymPodConfigurator(_symPodConfigurator);
    ETH2_DEPOSIT_CONTRACT = IETH2DepositContract(_eth2DepositContract);
    WITHDRAW_DELAY_PERIOD_SECONDS = _withdrawDelayPeriod;
    BEACON_ROOTS_ORACLE_ADDRESS = _beaconRootsOracle;
    BALANCE_DELTA_PERCENT = _balanceDelta;
  }

  /// @notice payable fallback function that receives ether deposited to the contract
  receive() external payable {
    emit NonBeaconChainETHDeposited(msg.value);
  }

  /// @notice Initialize addresses important to the SymPod functionality.
  /// Called on deployment by the SymPodFactory
  /// @param _name pod name
  /// @param _symbol pod symbol
  /// @param _slasher address that can slash funds in the pod
  /// @param _admin Used to perform admin tasks
  /// @param _withdrawalAddress Address that receives ETH withdrawals
  /// @param _recoveryRecipient Address that receives any deposited token
  /// @dev This is called only once by the SymPodFactory
  function initialize(
    string memory _name,
    string memory _symbol,
    address _slasher,
    address _admin,
    address _withdrawalAddress,
    address _recoveryRecipient
  ) external initializer {
    if (_slasher == address(0)) revert SymPod__InvalidAddress();
    if (_admin == address(0)) revert SymPod__InvalidAdmin();
    if (_withdrawalAddress == address(0)) revert SymPod__InvalidWithdrawalAddress();
    if (_recoveryRecipient == address(0)) revert SymPod__InvalidRecoveryAddress();

    podName = _name;
    podSymbol = _symbol;
    admin = _admin;
    slasher = _slasher;
    withdrawalAddress = _withdrawalAddress;
    recoveryAddress = _recoveryRecipient;

    emit Initialized(_slasher, _admin, _withdrawalAddress, _recoveryRecipient);
  }

  /// @notice Create new validators
  /// @param pubkey validator public keys
  /// @param signature deposit validator signatures
  /// @param depositDataRoot deposit validator data roots
  function stake(bytes calldata pubkey, bytes calldata signature, bytes32 depositDataRoot) external payable override {
    ETH2_DEPOSIT_CONTRACT.deposit{value: msg.value}(pubkey, symPodWithdrawalCredentials(), signature, depositDataRoot);
  }

  /// @dev Start a checkpoint to verify the active validator set balance for this SymPod.
  /// @dev When compeleted, the podAdmin is allocated shares corresponding to:
  /// - the net change in ACTIVE validator balances
  /// - any SymPod ETH balance that hasn't yet been converted into shares
  /// @dev A checkpoint cannot be initiated if one is already in progress; the pod administrator
  /// must finalize the current balance epoch before starting a new one.
  /// @param revertIfNoBalance Revert if the SymPod ETH balance is zero.
  function startCheckpoint(bool revertIfNoBalance) external onlyAdmin {
    _startCheckpoint(revertIfNoBalance);
  }

  /// @dev Finalize the current checkpoint by submitting one or more validator proofs.
  /// Anyone can submit proofs, reducing `pendingProofs` for each validator proven.
  /// The total change in ACTIVE validator balance is tracked, and 0 balance validators are marked `WITHDRAWN`.
  /// @dev The checkpoint is finalized when `pendingProofs` reaches 0.
  /// @dev This function is only callable during an active checkpoint.
  /// @param balanceRegistryProof Verifies the balance registry list root against the checkpoint's `beaconBlockRoot`.
  /// @param validatorBalancesProof Verifies validator balances against the BeaconState balance registry root.
  function verifyBalanceCheckpointProofs(
    BeaconChainProofs.BalanceRegistryProof calldata balanceRegistryProof,
    BeaconChainProofs.BalancesMultiProof calldata validatorBalancesProof
  ) external {
    Checkpoint memory activeCheckpoint = currentCheckPoint;
    uint256 currentCheckpointTimestamp = activeCheckpoint.currentTimestamp;
    if (currentCheckpointTimestamp == 0) revert SymPod__InvalidCheckPointTimestamp();

    // verify the balance container proof
    BeaconChainProofs.verifyBalanceRootAgainstBlockRoot({
      beaconBlockRoot: activeCheckpoint.beaconBlockRoot,
      proof: balanceRegistryProof
    });
    // fetch the validator indices
    uint40[] memory validatorIndices = _getValidatorIndices(validatorBalancesProof.validatorPubKeyHashes);
    // verify the passed in proof and return validator balances
    uint256[] memory validatorBalances = BeaconChainProofs.verifyMultipleValidatorsBalance({
      balanceListRoot: balanceRegistryProof.balanceListRoot,
      proof: validatorBalancesProof.proof,
      validatorIndices: validatorIndices,
      validatorBalanceRoots: validatorBalancesProof.validatorBalanceRoots
    });

    uint256 exitedBalancesGwei = _processBalanceCheckpointProof(
      validatorBalancesProof,
      activeCheckpoint,
      validatorIndices,
      validatorBalances
    );

    // Write to Storage
    checkpointBalanceExitedGwei[uint64(lastCheckpointTimestamp)] += uint64(exitedBalancesGwei);
  }

  /// @notice Verify a multiple validator withdrawal credentials
  /// @param beaconTimestamp timestamp for beacon block oracle root
  /// @param validatorRegistryProof BeaconState validator registry root and merkle proof against block root
  /// @param validatorProof merkle multiproof for multiple validators fields
  function verifyValidatorWithdrawalCredentials(
    uint64 beaconTimestamp,
    BeaconChainProofs.ValidatorRegistryProof calldata validatorRegistryProof,
    BeaconChainProofs.ValidatorsMultiProof calldata validatorProof
  ) external {
    // this prevents verifying WC to advance checkpoint proofs
    if (currentCheckPointTimestamp > beaconTimestamp) revert SymPod__InvalidTimestamp();

    // Verify passed-in `validatorListRoot` against the beacon block root
    BeaconChainProofs.verifyValidatorListRootAgainstBlockRoot({
      beaconBlockRoot: getParentBeaconBlockRoot(beaconTimestamp),
      proof: validatorRegistryProof
    });

    // verify the passed validator multi proof
    BeaconChainProofs.verifyMultipleValidatorFields({
      validatorListRoot: validatorRegistryProof.validatorListRoot,
      validatorFields: validatorProof.validatorFields,
      proof: validatorProof.proof,
      validatorIndices: validatorProof.validatorIndices
    });

    (uint256 numberOfValidators, uint256 totalAmountToBeRestakedWei) =
      _verifyWithdrawalCredentials(validatorProof);

    // Write to storage
    numberOfActiveValidators += uint64(numberOfValidators);
    _increaseBalance(admin, totalAmountToBeRestakedWei);
  }

  /// @dev Expired conditions
  ///  - Validator's last checkpoint is older than `beaconTimestamp`
  ///  - Validator must be `ACTIVE` status on the SymPod
  ///  - Validator is slashed on the beacon chain
  /// @param beaconTimestamp beacon oracle timestamp
  /// @param validatorRegistryProof validator container root and merkle proof against block root
  /// @param validatorProof validator field proof for slashed validator
  function verifyExpiredBalance(
    uint64 beaconTimestamp,
    BeaconChainProofs.ValidatorRegistryProof calldata validatorRegistryProof,
    BeaconChainProofs.ValidatorProof calldata validatorProof
  ) external {
    bytes32 validatorPubKeyHash = validatorProof.validatorFields.getPubkeyHash();
    EthValidator memory currentValidatorInfo = validatorInfo[validatorPubKeyHash];

    if (currentValidatorInfo.lastCheckpointedAt > beaconTimestamp) revert SymPod__InvalidBeaconTimestamp();
    if (currentValidatorInfo.status != VALIDATOR_STATE.ACTIVE) revert SymPod__InvalidValidatorState();
    // validator must be slashed to mark stale
    if (validatorProof.validatorFields.isValidatorSlashed() == false) revert SymPod__ValidatorNotSlashed();

    // verify list root
    BeaconChainProofs.verifyValidatorListRootAgainstBlockRoot({
      beaconBlockRoot: getParentBeaconBlockRoot(beaconTimestamp),
      proof: validatorRegistryProof
    });

    // verify validator fields against validator list root
    BeaconChainProofs.verifyValidatorFields({
      validatorListRoot: validatorRegistryProof.validatorListRoot,
      validatorFields: validatorProof.validatorFields,
      validatorFieldsProof: validatorProof.proof,
      validatorIndex: validatorProof.validatorIndex
    });

    _startCheckpoint(false);
  }

  /// @dev  ExceedBalanceDelta conditions
  ///  - Validator's last checkpoint is older than `beaconTimestamp`
  ///  - Validator must be `Acitve` status on the SymPod
  ///  - Validator restakedAmountGwei vs it's current BeaconChain balance is less
  ///    than delta allowed i.e. currentBeaconChainBalance - restakedAmountGwei > delta
  ///    The allowed delta is calculated as a % of the restakedAmountGwei
  /// @param balanceRegistryProof BeaconState balance registry root and proof against Beacon block root
  /// @param balanceProof Verifies balance of a validator
  function verifyExceedBalanceDelta(
    uint64 beaconTimestamp,
    BeaconChainProofs.BalanceRegistryProof calldata balanceRegistryProof,
    BeaconChainProofs.BalanceProof calldata balanceProof
  ) external {
    bytes32 validatorPubKeyHash = balanceProof.validatorPubKeyHash;
    EthValidator memory currentValidatorInfo = validatorInfo[validatorPubKeyHash];

    if (currentValidatorInfo.lastCheckpointedAt > beaconTimestamp) revert SymPod__InvalidBeaconTimestamp();
    if (currentValidatorInfo.status != VALIDATOR_STATE.ACTIVE) revert SymPod__InvalidValidatorState();
    // verify the balance container proof
    BeaconChainProofs.verifyBalanceRootAgainstBlockRoot({
      beaconBlockRoot: getParentBeaconBlockRoot(uint64(block.timestamp)),
      proof: balanceRegistryProof
    });

    // verify validator balance against balance root
    BeaconChainProofs.verifyValidatorBalance({
      balanceListRoot: balanceRegistryProof.balanceListRoot,
      validatorIndex: currentValidatorInfo.validatorIndex,
      proof: balanceProof
    });

    uint256 currentValidatorBalanceGwei =
      BeaconChainProofs.getBalanceAtIndex(balanceProof.validatorBalanceRoot, currentValidatorInfo.validatorIndex);

    // reverts if current balance is greater than restakedBalanceGwei
    if (
      (currentValidatorBalanceGwei > currentValidatorInfo.restakedBalanceGwei)
        || (
          (currentValidatorInfo.restakedBalanceGwei - currentValidatorBalanceGwei)
            < _calculateMinimumBalanceDelta(currentValidatorInfo.restakedBalanceGwei)
        )
    ) revert SymPod__InvalidBalanceDelta();

    _startCheckpoint(false);
  }

  /// @dev Initiate withdrawal from the SymPod
  /// @param amountInWei amount of Ether to withdraw
  /// @param nonce to use to generate the withdrawal key
  function initWithdraw(uint256 amountInWei, uint256 nonce) external onlyAdmin returns (bytes32 withdrawalKey) {
    // Ensure withdrawal is not paused
    if (symPodConfigurator.isWithdrawalsPaused() == true) revert SymPod__WithdrawalsPaused();
    // prevents queueing of withdrawals
    if ((amountInWei + pendingAmountToWithdrawWei) > withdrawableRestakedPodWei) revert SymPod__InsufficientBalance();
    if (amountInWei == 0) revert SymPod__AmountInWei();
    if (amountInWei > _withdrawableAmountWei(msg.sender)) revert SymPod__ExceedBalance();

    withdrawalKey = _getWithdrawalKey(amountInWei, nonce);
    // confirm withdrawal does not exist
    if (withdrawalQueue[withdrawalKey].to != address(0)) revert SymPod__WithdrawalKeyExists();

    uint256 withdrawalTimestamp = block.timestamp + WITHDRAW_DELAY_PERIOD_SECONDS;

    // Write to Storage
    pendingAmountToWithdrawWei += amountInWei;
    withdrawalQueue[withdrawalKey] =
      WithdrawalInfo(msg.sender, withdrawalAddress, uint128(amountInWei), uint128(withdrawalTimestamp));

    emit WithdrawalInitiated(withdrawalKey, amountInWei, withdrawalTimestamp);
  }

  /// @dev Finalize withdrawal
  /// @param withdrawalKey Generated withdrawal key
  /// @return amountToTransfer amount of eth transferred
  function completeWithdraw(bytes32 withdrawalKey) external returns (uint256 amountToTransfer) {
    // Ensure withdrawal is not paused
    if (symPodConfigurator.isWithdrawalsPaused() == true) revert SymPod__WithdrawalsPaused();

    WithdrawalInfo memory withdrawalInfo = withdrawalQueue[withdrawalKey];
    uint256 cachedAvailableToWithdrawInWei = withdrawableRestakedPodWei;

    address withdrawAddress = withdrawalInfo.to;
    if (withdrawAddress == address(0)) revert SymPod__InvalidWithdrawalKey();
    if (withdrawalInfo.timestamp > block.timestamp) revert SymPod__WithdrawDelayPeriod();

    amountToTransfer = cachedAvailableToWithdrawInWei >= withdrawalInfo.amountInWei
      ? withdrawalInfo.amountInWei
      : cachedAvailableToWithdrawInWei;
    
    if (amountToTransfer == 0) return 0;

    uint256 sharesToBurn = convertToShares(amountToTransfer);

    // Write to Storage

    // update pending amount to withdraw
    // We use amountInWei here because if the user doesn't want exact amount
    // we need still need to deduct the amountInWei
    pendingAmountToWithdrawWei -= withdrawalInfo.amountInWei;

    _burn(withdrawalInfo.owner, sharesToBurn);
    delete withdrawalQueue[withdrawalKey];

    // update the total restaked eth
    totalRestakedETH -= amountToTransfer;
    // update the available execution layer eth
    withdrawableRestakedPodWei -= amountToTransfer;

    // Interactions
    emit WithdrawalFinalized(withdrawalKey, amountToTransfer, withdrawalInfo.amountInWei);

    withdrawAddress.safeTransferETH(amountToTransfer);
  }

  /// @notice Slash callback for burning shares and receiving underyling ETH.
  /// @dev A slashing does not incur
  /// @param amountWei amount of Ether to burn
  /// @dev Only the slasher can call this function.
  /// This withdraw doesn't have a delay period
  function onSlash(uint256 amountWei) external override nonReentrant returns (bytes32 withdrawalKey) {
    if (msg.sender != slasher) revert SymPod__NotSlasher();
    if (amountWei == 0) revert SymPod__AmountInWei();

    uint256 amountSharesBurn = convertToShares(amountWei);
    if (amountSharesBurn > balanceOf(msg.sender)) revert SymPod__InvalidAmountOfShares();

    withdrawalKey = _getWithdrawalKey(amountWei, block.timestamp);

    // Write to Storage
    pendingAmountToWithdrawWei += amountWei;
    withdrawalQueue[withdrawalKey] =
      WithdrawalInfo(msg.sender, msg.sender, uint128(amountWei), uint128(block.timestamp));

    emit Slashed(withdrawalKey, amountWei, block.timestamp);
  }

  /// @notice called by pod admin to remove any ERC20s deposited into the SymPod
  /// @param tokens array of tokens to withdraw
  /// @param amountsToWithdraw array of amounts to withdraw
  function recoverTokens(ERC20[] memory tokens, uint256[] memory amountsToWithdraw) external onlyAdmin {
    if (tokens.length != amountsToWithdraw.length) revert SymPod__InvalidTokenAndAmountSize();

    for (uint256 i = 0; i < tokens.length; i++) {
      tokens[i].safeTransfer(recoveryAddress, amountsToWithdraw[i]);
    }
  }

  /// @dev total amount of underlying asset
  function totalAssets() public view override returns (uint256 assets) {
    assets = totalRestakedETH;
  }

  /// @dev defines asset addresss
  function asset() public pure override returns (address) {
    return ETH_ADDRESS;
  }

  /// @dev decimals
  function decimals() public pure override returns (uint8) {
    return 18;
  }

  /// @dev Returns the pod name
  function name() public view override returns (string memory) {
    return podName;
  }

  /// @notice symbol
  function symbol() public view override returns (string memory) {
    return podSymbol;
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
    if ((block.timestamp - timestamp) > (BEACON_ROOTS_HISTORY_BUFFER_LENGTH * 12)) revert SymPod__TimestampOutOfRange();

    (bool success, bytes memory result) = BEACON_ROOTS_ORACLE_ADDRESS.staticcall(abi.encode(timestamp));
    if (!success && result.length > 0) revert SymPod__InvalidBlockRoot();
    return abi.decode(result, (bytes32));
  }

  /// @notice Returns the current checkpoint infor
  function getCurrentCheckpoint() external view returns (Checkpoint memory) {
    return currentCheckPoint;
  }

  /// @notice Returns the eth validatorInfo for a given validatorPubkeyHash
  function getValidatorInfo(bytes32 validatorPubkeyHash) external view returns (EthValidator memory) {
    return validatorInfo[validatorPubkeyHash];
  }

  /// @notice Returns the withdrawalInfo for a given withdrawal key
  function getWithdrawalInfo(bytes32 withdrawalKey) external view returns (WithdrawalInfo memory) {
    return withdrawalQueue[withdrawalKey];
  }

  /// @dev Generate withdrawal key
  /// @param weiAmount amount to withdraw
  /// @param nonce nonce to use for withdrawal key
  function getWithdrawalKey(uint256 weiAmount, uint256 nonce) external view returns (bytes32 withdrawalKey) {
    return _getWithdrawalKey(weiAmount, nonce);
  }

  /// @dev Returns validator indices using public key hashes
  function getValidatorIndices(bytes32[] calldata validatorPubKeyHashes)
    public 
    view
    returns (uint40[] memory validatorIndices) 
  {
    return _getValidatorIndices(validatorPubKeyHashes);
  }

  /// @dev Generate withdrawal key
  function _getWithdrawalKey(uint256 weiAmount, uint256 nonce) internal view returns (bytes32 withdrawalKey) {
    withdrawalKey = keccak256(abi.encode(msg.sender, weiAmount, block.timestamp, nonce));
  }

  /// @dev Calculates a user withdrawable amount
  /// @param user address of user
  function _withdrawableAmountWei(address user) internal view returns (uint256 amount) {
    amount = convertToAssets(balanceOf(user));
  }

  /// @notice Process balance checkpoint proof
  function _processBalanceCheckpointProof(
    BeaconChainProofs.BalancesMultiProof calldata validatorBalancesProof,
    Checkpoint memory activeCheckpoint,
    uint40[] memory validatorIndices,
    uint256[] memory validatorBalances
  ) internal returns (uint256 exitedBalancesGwei) {
    // process the proof
    uint256 currentCheckpointTimestamp = activeCheckpoint.currentTimestamp;
    uint256 i = 0;
    uint256 size = validatorBalancesProof.validatorPubKeyHashes.length;

    for (; i < size; i++) {
      // check it's a active validator
      bytes32 validatorPubKeyHash = validatorBalancesProof.validatorPubKeyHashes[i];
      uint256 currentValidatorIndex = validatorIndices[i];
      EthValidator memory currentValidatorInfo = validatorInfo[validatorPubKeyHash];

      /// Check if the validator isn't active and skip
      if (currentValidatorInfo.status != VALIDATOR_STATE.ACTIVE) continue;
      // check if the validator has been checkpointed
      if (currentValidatorInfo.lastCheckpointedAt >= activeCheckpoint.currentTimestamp) continue;

      uint64 prevValidatorBalanceGwei = currentValidatorInfo.restakedBalanceGwei;
      uint64 newValidatorBalanceGwei = uint64(validatorBalances[i]);

      int256 balanceDeltaGwei = 0;
      if (prevValidatorBalanceGwei != newValidatorBalanceGwei) {
        balanceDeltaGwei = int256(uint256(newValidatorBalanceGwei)) - int256(uint256(prevValidatorBalanceGwei));
        emit ValidatorBalanceUpdated(
          currentValidatorIndex, activeCheckpoint.currentTimestamp, prevValidatorBalanceGwei, newValidatorBalanceGwei
        );
      }

      // Update validator info memory
      currentValidatorInfo.restakedBalanceGwei = newValidatorBalanceGwei;
      currentValidatorInfo.lastCheckpointedAt = uint64(currentCheckpointTimestamp);
      if (newValidatorBalanceGwei == 0) {
        currentValidatorInfo.status = VALIDATOR_STATE.WITHDRAWN;
        // reaching here means balanceDelta will be negative
        exitedBalancesGwei += uint256(int256(-balanceDeltaGwei));
      }

      // Update checkpoint info memory
      activeCheckpoint.pendingProofs--;
      activeCheckpoint.balanceDeltasGwei += int128(balanceDeltaGwei);

      // Write to Storage
      if (newValidatorBalanceGwei == 0) numberOfActiveValidators--;
      validatorInfo[validatorPubKeyHash] = currentValidatorInfo;

      emit ValidatorCheckpointUpdate(currentCheckpointTimestamp, currentValidatorIndex);
    }

    // Update checkpoint
    _updateCheckpoint(activeCheckpoint);
  }

  /// @notice Verify withdrawal credentials
  function _verifyWithdrawalCredentials(
    BeaconChainProofs.ValidatorsMultiProof calldata validatorData
  ) internal returns (uint256 numberOfValidators, uint256 totalAmountToBeRestakedWei) {
    numberOfValidators = validatorData.validatorFields.length;
    // NB: `lastCheckpointedAt` will be zero here if no checkpoint as been started previously. 
    // This is ok because the goal of `lastCheckpointedAt` is to ensure that newly-verified validators are not
    // eligible to progress already-existing checkpoints - however in this case, no checkpoints exist.
    uint64 lastCheckpointedAt = currentCheckPointTimestamp == 0 ? lastCheckpointTimestamp : currentCheckPointTimestamp;

    for (uint256 i = 0; i < numberOfValidators;) {
      uint40 validatorIndex = validatorData.validatorIndices[i];
      bytes32 validatorPubKeyHash = validatorData.validatorFields[i].getPubkeyHash();
      // verify validator state
      _verifyValidatorState(validatorPubKeyHash, validatorData.validatorFields[i]);
      // verify withdrawal credentials
      _verifyValidatorWithdrawalCredentials(validatorData.validatorFields[i]);

      // We use the effective balance here instead of the balance list root
      uint256 restakedBalanceGwei = validatorData.validatorFields[i].getEffectiveBalanceGwei();
      // accumulate total restaked eth
      totalAmountToBeRestakedWei += restakedBalanceGwei;

      // Emit events
      emit ValidatorRestaked(validatorPubKeyHash, validatorIndex, restakedBalanceGwei, lastCheckpointedAt);

      // Write to Storage
      validatorInfo[validatorPubKeyHash] = EthValidator({
        validatorIndex: validatorIndex,
        restakedBalanceGwei: uint64(restakedBalanceGwei),
        lastCheckpointedAt: uint64(lastCheckpointedAt),
        status: VALIDATOR_STATE.ACTIVE
      });

      unchecked {
        i++;
      }
    }

    totalAmountToBeRestakedWei = totalAmountToBeRestakedWei * GWEI_TO_WEI;
  }

  /// @notice increase balance
  /// @param to address to increase balance
  /// @param assetsWei amount of assets to credit
  function _increaseBalance(address to, uint256 assetsWei) internal {
    if ((assetsWei + totalAssets()) > maxDeposit(to)) revert DepositMoreThanMax();

    uint256 shares = convertToShares(assetsWei);

    // Write to storage
    _mint(to, shares);
    totalRestakedETH += assetsWei;

    emit IncreasedBalance(totalRestakedETH, shares);
  }

  /// @dev Start a checkpoint by snapshotting both the SymPod ETH balance and the
  /// current block's parent block root. After providing a balance proof for the
  /// pod's ACTIVE validators, the pod's ETH balance is awarded shares and can be withdrawn.
  /// @dev ACTIVE validators are validators with verified withdrawal credentials (See
  /// `verifyWithdrawalCredentials` for details)
  /// @dev If the SymPod does not have any ACTIVE validators, the checkpoint is automatically
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

    // prevent checkpoint from being able to start twice in a block
    // This is necessary because in _verifyCheckPointProof we skip for a validator
    // when its lastCheckpointedAt >= currentCheckPointTimestamp
    if (lastCheckpointTimestamp == uint64(block.timestamp)) revert SymPod__CannotActivateCheckPoint();

    // pod balance minus already accounted balance
    // We do not track less than 1 gwei balance on the pod
    uint64 podBalanceGwei =
      uint64(uint256(address(this).balance / GWEI_TO_WEI)) - uint64(uint256(withdrawableRestakedPodWei / GWEI_TO_WEI));

    if (revertIfNoBalance && podBalanceGwei == 0) revert SymPod__RevertIfNoBalance();

    Checkpoint memory checkpoint = Checkpoint({
      beaconBlockRoot: getParentBeaconBlockRoot(uint64(block.timestamp)),
      pendingProofs: uint24(numberOfActiveValidators),
      podBalanceGwei: podBalanceGwei,
      currentTimestamp: uint40(block.timestamp),
      balanceDeltasGwei: 0
    });

    // Write to Storage
    currentCheckPointTimestamp = uint64(block.timestamp);

    _updateCheckpoint(checkpoint);

    emit CheckpointCreated(uint64(block.timestamp), checkpoint.beaconBlockRoot, checkpoint.pendingProofs);
  }

  function _updateCheckpoint(Checkpoint memory checkpoint) internal {
    if (checkpoint.pendingProofs == 0) {
      int256 totalDeltaWei =
        (int128(uint128(checkpoint.podBalanceGwei)) + (checkpoint.balanceDeltasGwei)) * int256(GWEI_TO_WEI);

      // Write to Storage
      withdrawableRestakedPodWei += (checkpoint.podBalanceGwei * GWEI_TO_WEI);
      // Finalize the checkpoint
      lastCheckpointTimestamp = currentCheckPointTimestamp;

      delete currentCheckPointTimestamp;
      delete currentCheckPoint;

      if (totalDeltaWei > 0) {
        // should mint additional shares to admin
        _increaseBalance(admin, uint256(totalDeltaWei));
      } else if (totalDeltaWei < 0) {
        // decrease balance
        totalRestakedETH -= uint256(-totalDeltaWei);
      }

      emit CheckpointCompleted(lastCheckpointTimestamp, totalDeltaWei);
    } else {
      currentCheckPoint = checkpoint;
    }
  }

  function _verifyValidatorWithdrawalCredentials(bytes32[] calldata validatorFields) internal view virtual {
    bytes32 withdrawalCredentials = validatorFields.getWithdrawalCredentials();
    if (withdrawalCredentials != bytes32(symPodWithdrawalCredentials())) {
      revert SymPod__InvalidValidatorWithdrawalCredentials();
    }
  }

  function _verifyValidatorState(
    bytes32 validatorPubKeyHash,
    bytes32[] calldata validatorFields
  ) internal view {
    EthValidator memory currentValidatorInfo = validatorInfo[validatorPubKeyHash];
    if (currentValidatorInfo.status != VALIDATOR_STATE.INACTIVE) revert SymPod__InvalidValidatorState();

    uint64 exitEpoch = validatorFields.getExitEpoch();
    if (exitEpoch != BeaconChainProofs.FAR_FUTURE_EPOCH) revert SymPod__InvalidValidatorExitEpoch();

    uint64 activationEpoch = validatorFields.getActivationEpoch();
    if (activationEpoch == BeaconChainProofs.FAR_FUTURE_EPOCH) revert SymPod__InvalidValidatorActivationEpoch();
  }


  /// @dev Returns the validator indices using the pubkeyhashes
  function _getValidatorIndices(bytes32[] calldata validatorPubKeyHashes)
    internal
    view
    returns (uint40[] memory validatorIndices)
  {
    uint256 i = 0;
    uint256 size = validatorPubKeyHashes.length;
    validatorIndices = new uint40[](validatorPubKeyHashes.length);
    for (i; i < size;) {
      validatorIndices[i] = validatorInfo[validatorPubKeyHashes[i]].validatorIndex;
      unchecked {
        i += 1;
      }
    }
  }

  /// @dev Calculates minimum balance delta
  function _calculateMinimumBalanceDelta(uint256 balance) internal view returns (uint256 delta) {
    delta = (balance * BALANCE_DELTA_PERCENT) / PERCENTAGE;
  }

  function deposit(uint256, address) public pure override returns (uint256) {
    revert SymPod__NotImplemented();
  }

  function mint(uint256, address) public pure override returns (uint256) {
    revert SymPod__NotImplemented();
  }

  function withdraw(uint256, address, address) public pure override returns (uint256) {
    revert SymPod__NotImplemented();
  }

  function redeem(uint256, address, address) public pure override returns (uint256) {
    revert SymPod__NotImplemented();
  }

  function previewDeposit(uint256) public pure override returns (uint256) {
    revert SymPod__NotImplemented();
  }

  function previewRedeem(uint256) public pure override returns (uint256) {
    revert SymPod__NotImplemented();
  }
}
