// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IDepositContract} from "../interfaces/IDepositContract.sol";

/// @title OptimisticWithdrawalRecipientV2
/// @author Obol
/// @notice A maximally-composable contract that distributes payments
/// based on threshold to it's recipients.
/// @dev Only ETH can be distributed for a given deployment. There is a
/// recovery method for tokens sent by accident.
contract OptimisticWithdrawalRecipientV2 is OwnableRoles {
  /// -----------------------------------------------------------------------
  /// libraries
  /// -----------------------------------------------------------------------

  using SafeTransferLib for address;

  /// -----------------------------------------------------------------------
  /// errors
  /// -----------------------------------------------------------------------

  // The instance is already initialized
  error Invalid_AlreadyInitialized();

  // Invalid request params, e.g. empty input
  error InvalidRequest_Params();

  // Failed to call system contract get_fee()
  error InvalidRequest_SystemGetFee();

  // Insufficient fee provided in the call's value to conclude the request
  error InvalidRequest_NotEnoughFee();

  // Failed to call system contract add_consolidation_request()
  error InvalidConsolidation_Failed();

  // Failed to call system contract add_withdrawal_request()
  error InvalidWithdrawal_Failed();

  /// Invalid token recovery recipient
  error InvalidTokenRecovery_InvalidRecipient();

  /// Invalid distribution
  error InvalidDistribution_TooLarge();

  /// -----------------------------------------------------------------------
  /// events
  /// -----------------------------------------------------------------------

  /// Emitted after funds are distributed to recipients
  /// @param principalPayout Amount of principal paid out
  /// @param rewardPayout Amount of reward paid out
  /// @param pullOrPush Flag indicating PULL or PUSH flow
  event DistributeFunds(uint256 principalPayout, uint256 rewardPayout, uint256 pullOrPush);

  /// Emitted after tokens are recovered to a recipient
  /// @param recoveryAddressToken Recovered token (cannot be ETH)
  /// @param recipient Address receiving recovered token
  /// @param amount Amount of recovered token
  event RecoverNonOWRecipientFunds(address indexed recoveryAddressToken, address indexed recipient, uint256 amount);

  /// Emitted after funds withdrawn using pull flow
  /// @param account Account withdrawing funds for
  /// @param amount Amount withdrawn
  event Withdrawal(address indexed account, uint256 amount);

  /// Emitted when a Pectra consolidation request is done
  /// @param requester Address of the requester
  /// @param source Source validator public key
  /// @param target Target validator public key
  event ConsolidationRequested(address indexed requester, bytes indexed source, bytes indexed target);

  /// Emitted when a Pectra withdrawal request is done
  /// @param requester Address of the requester
  /// @param pubKey Validator public key
  /// @param amount Withdrawal amount
  event WithdrawalRequested(address indexed requester, bytes indexed pubKey, uint256 amount);

  /// -----------------------------------------------------------------------
  /// storage
  /// -----------------------------------------------------------------------

  /// -----------------------------------------------------------------------
  /// storage - constants
  /// -----------------------------------------------------------------------

  uint256 public constant WITHDRAWAL_ROLE = 0x01;
  uint256 public constant CONSOLIDATION_ROLE = 0x02;

  uint256 internal constant PUSH = 0;
  uint256 internal constant PULL = 1;

  /// -----------------------------------------------------------------------
  /// storage - immutable
  /// -----------------------------------------------------------------------

  address public immutable consolidationSystemContract;
  address public immutable withdrawalSystemContract;
  address public immutable depositSystemContract;
  address public immutable recoveryAddress;
  address public immutable principalRecipient;
  address public immutable rewardRecipient;
  uint256 public immutable principalThreshold;

  /// -----------------------------------------------------------------------
  /// storage - mutables
  /// -----------------------------------------------------------------------
  /// @dev set to `true` after owner is initialized
  bool public initialized;

  /// Amount of principal stake done via deposit() calls
  uint256 public amountOfPrincipalStake;

  /// Amount of active balance set aside for pulls
  /// @dev ERC20s with very large decimals may overflow & cause issues
  uint128 public fundsPendingWithdrawal;

  /// Mapping to account balances for pulling
  mapping(address => uint256) internal pullBalances;

  /// -----------------------------------------------------------------------
  /// constructor
  /// -----------------------------------------------------------------------

  constructor(
    address _consolidationSystemContract,
    address _withdrawalSystemContract,
    address _depositSystemContract,
    address _recoveryAddress,
    address _principalRecipient,
    address _rewardRecipient,
    uint256 _principalThreshold
  ) {
    consolidationSystemContract = _consolidationSystemContract;
    withdrawalSystemContract = _withdrawalSystemContract;
    depositSystemContract = _depositSystemContract;
    recoveryAddress = _recoveryAddress;
    principalRecipient = _principalRecipient;
    rewardRecipient = _rewardRecipient;
    principalThreshold = _principalThreshold;
  }

  /// -----------------------------------------------------------------------
  /// functions
  /// -----------------------------------------------------------------------

  /// -----------------------------------------------------------------------
  /// functions - public & external
  /// -----------------------------------------------------------------------

  /// @dev initializes the owner
  /// @param _owner the owner address
  function initialize(address _owner) public {
    if (initialized) revert Invalid_AlreadyInitialized();
    _initializeOwner(_owner);
    initialized = true;
  }

  /// @dev Fallback function to receive ETH
  ///      Because we do not use Clone, we must implement this explicitly
  receive() external payable {}

  /// @notice Submit a Phase 0 DepositData object.
  /// @param pubkey A BLS12-381 public key.
  /// @param withdrawal_credentials Commitment to a public key for withdrawals.
  /// @param signature A BLS12-381 signature.
  /// @param deposit_data_root The SHA-256 hash of the SSZ-encoded DepositData object.
  /// Used as a protection against malformed input.
  /// @dev This function is a proxy to the deposit() function on the depositSystemContract.
  ///      The deposited amount is added to the principal stake.
  ///      Any deposits made directly to the depositSystemContract will not be accounted for.
  function deposit(
    bytes calldata pubkey,
    bytes calldata withdrawal_credentials,
    bytes calldata signature,
    bytes32 deposit_data_root
  ) external payable {
    IDepositContract(depositSystemContract).deposit{value: msg.value}(pubkey, withdrawal_credentials, signature, deposit_data_root);
    amountOfPrincipalStake += msg.value;
  }

  /// Distributes target token inside the contract to recipients
  /// @dev pushes funds to recipients
  function distributeFunds() external payable {
    _distributeFunds(PUSH);
  }

  /// Distributes target token inside the contract to recipients
  /// @dev backup recovery if any recipient tries to brick the OWRecipient for
  /// remaining recipients
  function distributeFundsPull() external payable {
    _distributeFunds(PULL);
  }

  /// Request validators consolidation with the EIP7251 system contract
  /// @dev all source validators will be consolidated into the target validator
  ///      the caller must compute the fee before calling and send a sufficient msg.value amount
  ///      excess amount will be refunded
  /// @param sourcePubKeys validator public keys to be consolidated
  /// @param targetPubKey target validator public key
  function requestConsolidation(
    bytes[] calldata sourcePubKeys,
    bytes calldata targetPubKey
  ) external payable onlyOwnerOrRoles(CONSOLIDATION_ROLE) {
    if (sourcePubKeys.length == 0 || targetPubKey.length != 48) revert InvalidRequest_Params();

    uint256 remainingFee = msg.value;
    uint256 len = sourcePubKeys.length;

    for (uint256 i; i < len; ) {
      uint256 _currentFee = _computeSystemContractFee(consolidationSystemContract);
      if (_currentFee > remainingFee) revert InvalidRequest_NotEnoughFee();

      remainingFee -= _currentFee;
      _requestConsolidation(sourcePubKeys[i], targetPubKey, _currentFee);

      unchecked {
        ++i;
      }
    }

    // Future optimization idea: do not send if gas cost exceeds the value.
    if (remainingFee > 0) payable(msg.sender).transfer(remainingFee);
  }

  /// Request partial/full withdrawal from the EIP7002 system contract
  /// @dev the caller must compute the fee before calling and send a sufficient msg.value amount
  ///      excess amount will be refunded
  ///      withdrawals that leave a validator with (0..32) ether will cause the transaction to fail
  /// @param pubKeys validator public keys
  /// @param amounts withdrawal amounts in gwei
  function requestWithdrawal(
    bytes[] calldata pubKeys,
    uint64[] calldata amounts
  ) external payable onlyOwnerOrRoles(WITHDRAWAL_ROLE) {
    if (pubKeys.length != amounts.length) revert InvalidRequest_Params();

    uint256 remainingFee = msg.value;
    uint256 len = pubKeys.length;

    for (uint256 i; i < len; ) {
      uint256 _currentFee = _computeSystemContractFee(withdrawalSystemContract);
      if (_currentFee > remainingFee) revert InvalidRequest_NotEnoughFee();

      remainingFee -= _currentFee;
      _requestWithdrawal(pubKeys[i], amounts[i], _currentFee);

      unchecked {
        ++i;
      }
    }

    // Future optimization idea: do not send if gas cost exceeds the value.
    if (remainingFee > 0) payable(msg.sender).transfer(remainingFee);
  }

  /// Recover non-OWR tokens to a recipient
  /// @param nonOWRToken Token to recover (cannot be OWR token)
  /// @param recipient Address to receive recovered token
  function recoverFunds(address nonOWRToken, address recipient) external payable {
    /// checks

    // if recoveryAddress is set, recipient must match it
    // else, recipient must be one of the OWR recipients
    if (recoveryAddress == address(0)) {
      // ensure txn recipient is a valid OWR recipient
      if (recipient != principalRecipient && recipient != rewardRecipient) {
        revert InvalidTokenRecovery_InvalidRecipient();
      }
    } else if (recipient != recoveryAddress) {
      revert InvalidTokenRecovery_InvalidRecipient();
    }

    /// effects

    /// interactions

    // recover non-target token
    uint256 amount = ERC20(nonOWRToken).balanceOf(address(this));
    nonOWRToken.safeTransfer(recipient, amount);

    emit RecoverNonOWRecipientFunds(nonOWRToken, recipient, amount);
  }

  /// Withdraw token balance for account
  /// @param account Address to withdraw on behalf of
  function withdraw(address account) external {
    uint256 amount = pullBalances[account];
    unchecked {
      // shouldn't underflow; fundsPendingWithdrawal = sum(pullBalances)
      fundsPendingWithdrawal -= uint128(amount);
    }
    pullBalances[account] = 0;
    account.safeTransferETH(amount);

    emit Withdrawal(account, amount);
  }

  /// -----------------------------------------------------------------------
  /// functions - view & pure
  /// -----------------------------------------------------------------------

  /// Returns the balance for account `account`
  /// @param account Account to return balance for
  /// @return Account's withdrawable ether balance
  function getPullBalance(address account) external view returns (uint256) {
    return pullBalances[account];
  }

  /// -----------------------------------------------------------------------
  /// functions - private & internal
  /// -----------------------------------------------------------------------

  /// Compute system contracts fee
  function _computeSystemContractFee(address systemContractAddress) internal view returns (uint256) {
    (bool ok, bytes memory result) = systemContractAddress.staticcall("");
    if (!ok) revert InvalidRequest_SystemGetFee();

    return uint256(bytes32(result));
  }

  /// Executes single consolidation request
  function _requestConsolidation(bytes calldata source, bytes calldata target, uint256 fee) private {
    if (source.length != 48 || target.length != 48) revert InvalidRequest_Params();

    // Input data has the following layout:
    //
    //  +--------+--------+
    //  | source | target |
    //  +--------+--------+
    //      48       48

    (bool ok, ) = consolidationSystemContract.call{value: fee}(bytes.concat(source, target));
    if (!ok) revert InvalidConsolidation_Failed();

    emit ConsolidationRequested(msg.sender, source, target);
  }

  /// Executes single withdrawal request
  function _requestWithdrawal(bytes memory pubkey, uint64 amount, uint256 fee) private {
    if (pubkey.length != 48) revert InvalidRequest_Params();

    // Input data has the following layout:
    //
    //  +--------+--------+
    //  | pubkey | amount |
    //  +--------+--------+
    //      48       8
    (bool ret, ) = withdrawalSystemContract.call{value: fee}(abi.encodePacked(pubkey, amount));
    if (!ret) revert InvalidWithdrawal_Failed();

    emit WithdrawalRequested(msg.sender, pubkey, amount);
  }

  /// Distributes target token inside the contract to next-in-line recipients
  /// @dev can PUSH or PULL funds to recipients
  function _distributeFunds(uint256 pullOrPush) internal {
    /// checks

    /// effects

    // load storage into memory
    uint256 currentbalance = address(this).balance;
    uint256 _memoryFundsPendingWithdrawal = uint256(fundsPendingWithdrawal);
    uint256 _fundsToBeDistributed = currentbalance - _memoryFundsPendingWithdrawal;

    // determine which recipeint is getting paid based on funds to be
    // distributed
    uint256 _principalPayout = 0;
    uint256 _rewardPayout = 0;

    unchecked {
      if (_fundsToBeDistributed >= principalThreshold && amountOfPrincipalStake > 0) {
        if (_fundsToBeDistributed > amountOfPrincipalStake) {
          // this means there is reward part of the funds to be
          // distributed
          _principalPayout = amountOfPrincipalStake;
          // shouldn't underflow
          _rewardPayout = _fundsToBeDistributed - amountOfPrincipalStake;
        } else {
          // this means there is no reward part of the funds to be
          // distributed
          _principalPayout = _fundsToBeDistributed;
        }
      } else {
        _rewardPayout = _fundsToBeDistributed;
      }
    }

    {
      if (_fundsToBeDistributed > type(uint128).max) revert InvalidDistribution_TooLarge();
      // Write to storage
      // the principal value
      // it cannot overflow because _principalPayout < _fundsToBeDistributed
      if (_principalPayout > 0) amountOfPrincipalStake -= uint128(_principalPayout);
    }

    /// interactions

    // pay outs
    // earlier tranche recipients may try to re-enter but will cause fn to
    // revert
    // when later external calls fail (bc balance is emptied early)

    // pay out principal
    _payout(principalRecipient, _principalPayout, pullOrPush);
    // pay out reward
    _payout(rewardRecipient, _rewardPayout, pullOrPush);

    if (pullOrPush == PULL) {
      if (_principalPayout > 0 || _rewardPayout > 0) {
        // Write to storage
        fundsPendingWithdrawal = uint128(_memoryFundsPendingWithdrawal + _principalPayout + _rewardPayout);
      }
    }

    emit DistributeFunds(_principalPayout, _rewardPayout, pullOrPush);
  }

  function _payout(address recipient, uint256 payoutAmount, uint256 pullOrPush) internal {
    if (payoutAmount > 0) {
      if (pullOrPush == PULL) {
        // Write to Storage
        pullBalances[recipient] += payoutAmount;
      } else if (pullOrPush == PUSH) {
        recipient.safeTransferETH(payoutAmount);
      } else {
        revert InvalidRequest_Params();
      }
    }
  }
}
