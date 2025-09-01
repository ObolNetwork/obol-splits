// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IDepositContract} from "../interfaces/IDepositContract.sol";
import {IObolValidatorManager} from "../interfaces/IObolValidatorManager.sol";

/// @title ObolValidatorManager
/// @author Obol
/// @notice A maximally-composable contract that distributes payments
/// based on threshold to its recipients.
/// @dev Only ETH can be distributed for a given deployment. There is a
/// recovery method for tokens sent by accident.
contract ObolValidatorManager is IObolValidatorManager, OwnableRoles {
  /// -----------------------------------------------------------------------
  /// libraries
  /// -----------------------------------------------------------------------

  using SafeTransferLib for address;

  /// -----------------------------------------------------------------------
  /// errors
  /// -----------------------------------------------------------------------

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

  /// Invalid distribution
  error InvalidDistribution_TooLarge();

  /// -----------------------------------------------------------------------
  /// events
  /// -----------------------------------------------------------------------

  /// Emitted after principal recipient is changed
  /// @param newPrincipalRecipient New principal recipient address
  /// @param oldPrincipalRecipient Old principal recipient address
  event NewPrincipalRecipient(address indexed newPrincipalRecipient, address indexed oldPrincipalRecipient);

  /// Emitted after funds are distributed to recipients
  /// @param principalPayout Amount of principal paid out
  /// @param rewardPayout Amount of reward paid out
  /// @param pullOrPush Flag indicating PULL or PUSH flow
  event DistributeFunds(uint256 principalPayout, uint256 rewardPayout, uint256 pullOrPush);

  /// Emitted after tokens are recovered to a recipient
  /// @param nonOVMToken Recovered token (cannot be ETH)
  /// @param recipient Address receiving recovered token
  /// @param amount Amount of recovered token
  event RecoverNonOVMFunds(address indexed nonOVMToken, address indexed recipient, uint256 amount);

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
  uint256 public constant SET_PRINCIPAL_ROLE = 0x04;
  uint256 public constant RECOVER_FUNDS_ROLE = 0x08;

  uint256 internal constant PUSH = 0;
  uint256 internal constant PULL = 1;

  uint256 internal constant PUBLIC_KEY_LENGTH = 48;

  /// -----------------------------------------------------------------------
  /// storage - immutable
  /// -----------------------------------------------------------------------

  address public immutable consolidationSystemContract;
  address public immutable withdrawalSystemContract;
  address public immutable depositSystemContract;
  address public immutable rewardRecipient;
  uint64 public immutable principalThreshold;

  /// -----------------------------------------------------------------------
  /// storage - mutables
  /// -----------------------------------------------------------------------

  /// Address to receive principal funds
  address public principalRecipient;

  /// Amount of principal stake (wei) done via deposit() calls
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
    address _owner,
    address _principalRecipient,
    address _rewardRecipient,
    uint64 _principalThreshold
  ) {
    consolidationSystemContract = _consolidationSystemContract;
    withdrawalSystemContract = _withdrawalSystemContract;
    depositSystemContract = _depositSystemContract;
    principalRecipient = _principalRecipient;
    rewardRecipient = _rewardRecipient;
    principalThreshold = _principalThreshold;

    _initializeOwner(_owner);
  }

  /// -----------------------------------------------------------------------
  /// functions
  /// -----------------------------------------------------------------------

  /// -----------------------------------------------------------------------
  /// functions - public & external
  /// -----------------------------------------------------------------------

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
  ///      The deposited amount is accounted for in the amountOfPrincipalStake, which is used
  ///      to determine the principalRecipient's share of the funds to be distributed.
  ///      Any deposits made directly to the depositSystemContract will not be accounted for
  ///      and will be sent to the rewardRecipient address.
  function deposit(
    bytes calldata pubkey,
    bytes calldata withdrawal_credentials,
    bytes calldata signature,
    bytes32 deposit_data_root
  ) external payable {
    amountOfPrincipalStake += msg.value;
    IDepositContract(depositSystemContract).deposit{value: msg.value}(
      pubkey,
      withdrawal_credentials,
      signature,
      deposit_data_root
    );
  }

  /// @notice Set the principal recipient address
  /// @param newPrincipalRecipient New address to receive principal funds
  function setPrincipalRecipient(address newPrincipalRecipient) external onlyOwnerOrRoles(SET_PRINCIPAL_ROLE) {
    if (newPrincipalRecipient == address(0)) {
      revert InvalidRequest_Params();
    }

    address oldPrincipalRecipient = principalRecipient;
    principalRecipient = newPrincipalRecipient;

    emit NewPrincipalRecipient(newPrincipalRecipient, oldPrincipalRecipient);
  }

  /// Distributes target token inside the contract to recipients
  /// @dev pushes funds to recipients
  function distributeFunds() external {
    _distributeFunds(PUSH);
  }

  /// Distributes target token inside the contract to recipients
  /// @dev Backup recovery if any recipient tries to brick the OVM for
  /// remaining recipients
  function distributeFundsPull() external {
    _distributeFunds(PULL);
  }

  /// Request validators consolidation with the EIP7251 system contract
  /// @dev All source validators will be consolidated into the target validator.
  ///      The caller must compute the fee before calling and send a sufficient msg.value amount.
  ///      Excess amount will be refunded.
  /// @param sourcePubKeys Validator public keys to be consolidated
  /// @param targetPubKey Target validator public key
  function requestConsolidation(
    bytes[] calldata sourcePubKeys,
    bytes calldata targetPubKey
  ) external payable onlyOwnerOrRoles(CONSOLIDATION_ROLE) {
    if (sourcePubKeys.length == 0 || sourcePubKeys.length > 63 || targetPubKey.length != PUBLIC_KEY_LENGTH)
      revert InvalidRequest_Params();

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
  /// @dev The caller must compute the fee before calling and send a sufficient msg.value amount.
  ///      Excess amount will be refunded.
  ///      Withdrawals that leave a validator with (0..32) ether
  ///      will only withdraw an amount that leaves the validator at 32 ether.
  /// @param pubKeys Validator public keys
  /// @param amounts Withdrawal amounts in gwei.
  ///                Any amount below principalThreshold will be distributed as reward.
  ///                Any amount >= principalThreshold will be distributed as principal.
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

  /// Recover non-OVM tokens to a recipient
  /// @param nonOVMToken Token to recover (cannot be OVM token)
  /// @param recipient Address to receive recovered token
  function recoverFunds(address nonOVMToken, address recipient) external onlyOwnerOrRoles(RECOVER_FUNDS_ROLE) {
    uint256 amount = ERC20(nonOVMToken).balanceOf(address(this));
    nonOVMToken.safeTransfer(recipient, amount);

    emit RecoverNonOVMFunds(nonOVMToken, recipient, amount);
  }

  /// Withdraw token balance for an account
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

  /// Returns the balance for the account `account`
  /// @param account Account to return balance for
  /// @return Account's withdrawable ether balance
  function getPullBalance(address account) external view returns (uint256) {
    return pullBalances[account];
  }

  /// -----------------------------------------------------------------------
  /// OwnableRoles function overrides
  /// -----------------------------------------------------------------------

  /// @dev Allows the owner to grant `user` `roles`.
  /// If the `user` already has a role, then it will be a no-op for the role.
  function grantRoles(address user, uint256 roles) public payable override(IObolValidatorManager, OwnableRoles) {
    super.grantRoles(user, roles);
  }

  /// @dev Allows the owner to remove `user` `roles`.
  /// If the `user` does not have a role, then it will be a no-op for the role.
  function revokeRoles(address user, uint256 roles) public payable override(IObolValidatorManager, OwnableRoles) {
    super.revokeRoles(user, roles);
  }

  /// @dev Allow the caller to remove their own roles.
  /// If the caller does not have a role, then it will be a no-op for the role.
  function renounceRoles(uint256 roles) public payable override(IObolValidatorManager, OwnableRoles) {
    super.renounceRoles(roles);
  }

  /// @dev Returns the roles of `user`.
  function rolesOf(address user) public view override(IObolValidatorManager, OwnableRoles) returns (uint256 roles) {
    return super.rolesOf(user);
  }

  /// @dev Returns whether `user` has any of `roles`.
  function hasAnyRole(address user, uint256 roles) public view override(IObolValidatorManager, OwnableRoles) returns (bool) {
    return super.hasAnyRole(user, roles);
  }

  /// @dev Returns whether `user` has all of `roles`.
  function hasAllRoles(address user, uint256 roles) public view override(IObolValidatorManager, OwnableRoles) returns (bool) {
    return super.hasAllRoles(user, roles);
  }

  /// @dev Allows the owner to transfer the ownership to `newOwner`.
  function transferOwnership(address newOwner) public payable override(IObolValidatorManager, Ownable) {
    super.transferOwnership(newOwner);
  }

  /// @dev Allows the owner to renounce their ownership.
  function renounceOwnership() public payable override(IObolValidatorManager, Ownable) {
    super.renounceOwnership();
  }

  /// @dev Request a two-step ownership handover to the caller.
  /// The request will automatically expire in 48 hours (172800 seconds) by default.
  function requestOwnershipHandover() public payable override(IObolValidatorManager, Ownable) {
    super.requestOwnershipHandover();
  }

  /// @dev Cancels the two-step ownership handover to the caller, if any.
  function cancelOwnershipHandover() public payable override(IObolValidatorManager, Ownable) {
    super.cancelOwnershipHandover();
  }

  /// @dev Allows the owner to complete the two-step ownership handover to `pendingOwner`.
  /// Reverts if there is no existing ownership handover requested by `pendingOwner`.
  function completeOwnershipHandover(address pendingOwner) public payable override(IObolValidatorManager, Ownable) {
    super.completeOwnershipHandover(pendingOwner);
  }

  /// @dev Returns the owner of the contract.
  function owner() public view override(IObolValidatorManager, Ownable) returns (address result) {
    return super.owner();
  }

  /// @dev Returns the expiry timestamp for the two-step ownership handover to `pendingOwner`.
  function ownershipHandoverExpiresAt(address pendingOwner) public view override(IObolValidatorManager, Ownable) returns (uint256 result) {
    return super.ownershipHandoverExpiresAt(pendingOwner);
  }

  /// -----------------------------------------------------------------------
  /// functions - private & internal
  /// -----------------------------------------------------------------------

  /// Compute system contract's fee
  /// @param systemContractAddress Address of the consolidation system contract
  /// @return The computed fee
  function _computeSystemContractFee(address systemContractAddress) internal view returns (uint256) {
    (bool ok, bytes memory result) = systemContractAddress.staticcall("");
    if (!ok) revert InvalidRequest_SystemGetFee();

    return uint256(bytes32(result));
  }

  /// Execute a single consolidation request
  /// @param source Source validator public key
  /// @param target Target validator public key
  /// @param fee Fee for the consolidation request
  function _requestConsolidation(bytes calldata source, bytes calldata target, uint256 fee) private {
    if (source.length != PUBLIC_KEY_LENGTH || target.length != PUBLIC_KEY_LENGTH) revert InvalidRequest_Params();

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
    if (pubkey.length != PUBLIC_KEY_LENGTH) revert InvalidRequest_Params();

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
    uint256 principalThresholdWei = uint256(principalThreshold) * 1e9;

    // determine which recipeint is getting paid based on funds to be distributed
    uint256 _principalPayout = 0;
    uint256 _rewardPayout = 0;

    unchecked {
      if (_fundsToBeDistributed >= principalThresholdWei && amountOfPrincipalStake > 0) {
        if (_fundsToBeDistributed > amountOfPrincipalStake) {
          // this means there is reward part of the funds to be distributed
          _principalPayout = amountOfPrincipalStake;
          // shouldn't underflow
          _rewardPayout = _fundsToBeDistributed - amountOfPrincipalStake;
        } else {
          // this means there is no reward part of the funds to be distributed
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
