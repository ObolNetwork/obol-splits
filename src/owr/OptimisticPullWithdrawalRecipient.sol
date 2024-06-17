// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {Clone} from "solady/utils/Clone.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/// @title OptimisticPullOnlyWithdrawalRecipient
/// @author Obol
/// @notice A maximally-composable contract that distributes payments
/// based on threshold to it's recipients
/// @dev Only one token can be distributed for a given deployment. There is a
/// recovery method for non-target tokens sent by accident.
/// Target ERC20s with very large decimals may overflow & cause issues.
/// This contract uses token = address(0) to refer to ETH.
contract OptimisticPullWithdrawalRecipient is Clone {
  /// -----------------------------------------------------------------------
  /// libraries
  /// -----------------------------------------------------------------------

  using SafeTransferLib for address;

  /// -----------------------------------------------------------------------
  /// errors
  /// -----------------------------------------------------------------------

  /// Invalid token recovery; cannot recover the OWRecipient token
  error InvalidTokenRecovery_OWRToken();

  /// Invalid token recovery recipient
  error InvalidTokenRecovery_InvalidRecipient();

  /// Invalid distribution
  error InvalidDistribution_TooLarge();

  /// Invalid withdraw 
  error InvalidWithdrawAmount_TooLarge();

  /// -----------------------------------------------------------------------
  /// events
  /// -----------------------------------------------------------------------

  /// Emitted after each successful ETH transfer to proxy
  /// @param amount Amount of ETH received
  /// @dev embedded in & emitted from clone bytecode
  event ReceiveETH(uint256 amount);

  /// Emitted after funds are distributed to recipients
  /// @param principalPayout Amount of principal paid out
  /// @param rewardPayout Amount of reward paid out
  /// pulling
  event DistributeFunds(uint256 principalPayout, uint256 rewardPayout);

  /// Emitted after non-OWRecipient tokens are recovered to a recipient
  /// @param recoveryAddressToken Recovered token (cannot be
  /// OptimisticWithdrawalRecipient token)
  /// @param recipient Address receiving recovered token
  /// @param amount Amount of recovered token
  event RecoverNonOWRecipientFunds(address recoveryAddressToken, address recipient, uint256 amount);

  /// Emitted after funds withdrawn using pull flow
  /// @param account Account withdrawing funds for
  /// @param amount Amount withdrawn
  event Withdrawal(address account, uint256 amount);

  /// -----------------------------------------------------------------------
  /// storage
  /// -----------------------------------------------------------------------

  /// -----------------------------------------------------------------------
  /// storage - constants
  /// -----------------------------------------------------------------------

  address internal constant ETH_ADDRESS = address(0);

  uint256 internal constant ONE_WORD = 32;
  uint256 internal constant ADDRESS_BITS = 160;

  /// @dev threshold for pushing balance update as reward or principal
  uint256 internal constant BALANCE_CLASSIFICATION_THRESHOLD = 16 ether;
  uint256 internal constant PRINCIPAL_RECIPIENT_INDEX = 0;
  uint256 internal constant REWARD_RECIPIENT_INDEX = 1;

  /// -----------------------------------------------------------------------
  /// storage - cwia offsets
  /// -----------------------------------------------------------------------

  // token (address, 20 bytes), recoveryAddress (address, 20 bytes),
  // tranches (uint256[], numTranches * 32 bytes)

    // 0; first item
  uint256 internal constant TOKEN_OFFSET = 0;
  // 20 = token_offset (0) + token_size (address, 20 bytes)
  uint256 internal constant RECOVERY_ADDRESS_OFFSET = 20;
  // 40 = recoveryAddress_offset (20) + recoveryAddress_size (address, 20
  // bytes)
  uint256 internal constant TRANCHES_OFFSET = 40;

  /// Address of ERC20 to distribute (0x0 used for ETH)
  /// @dev equivalent to address public immutable token;
  function token() public pure returns (address) {
    return _getArgAddress(TOKEN_OFFSET);
  }

  /// Address to recover non-OWR tokens to
  /// @dev equivalent to address public immutable recoveryAddress;
  function recoveryAddress() public pure returns (address) {
    return _getArgAddress(RECOVERY_ADDRESS_OFFSET);
  }

  /// Get OWR tranche `i`
  /// @dev emulates to uint256[] internal immutable tranche;
  function _getTranche(uint256 i) internal pure returns (uint256) {
    unchecked {
      // shouldn't overflow
      return _getArgUint256(TRANCHES_OFFSET + i * ONE_WORD);
    }
  }

  /// -----------------------------------------------------------------------
  /// storage - mutables
  /// -----------------------------------------------------------------------

  /// Amount of active balance set aside for pulls
  /// @dev ERC20s with very large decimals may overflow & cause issues
  uint128 public fundsPendingWithdrawal;

  /// Amount of distributed OWRecipient token for principal
  /// @dev Would be less than or equal to amount of stake
  /// @dev ERC20s with very large decimals may overflow & cause issues
  uint128 public claimedPrincipalFunds;

  /// Mapping to account balances for pulling
  mapping(address => uint256) internal pullBalances;

  /// -----------------------------------------------------------------------
  /// constructor
  /// -----------------------------------------------------------------------

  // solhint-disable-next-line no-empty-blocks
  /// clone implementation doesn't use constructor
  constructor() {}

  /// -----------------------------------------------------------------------
  /// functions
  /// -----------------------------------------------------------------------

  /// -----------------------------------------------------------------------
  /// functions - public & external
  /// -----------------------------------------------------------------------

  /// emit event when receiving ETH
  /// @dev implemented w/i clone bytecode
  /* receive() external payable { */
  /*     emit ReceiveETH(msg.value); */
  /* } */

  /// Distributes target token inside the contract to recipients
  /// @dev pushes funds to recipients
  function distributeFunds() external payable {
    /// checks

    /// effects

    // load storage into memory
    // fetch the token we want to distribute
    address _token = token();
    uint256 currentbalance = _token == ETH_ADDRESS ? address(this).balance : ERC20(_token).balanceOf(address(this));
    uint256 _claimedPrincipalFunds = uint256(claimedPrincipalFunds);
    uint256 _memoryFundsPendingWithdrawal = uint256(fundsPendingWithdrawal);

    uint256 _fundsToBeDistributed = currentbalance - _memoryFundsPendingWithdrawal;

    (address principalRecipient, address rewardRecipient, uint256 amountOfPrincipalStake) = getTranches();

    // determine which recipeint is getting paid based on funds to be
    // distributed
    uint256 _principalPayout = 0;
    uint256 _rewardPayout = 0;

    unchecked {
      // _claimedPrincipalFunds should always be <= amountOfPrincipalStake
      uint256 principalStakeRemaining = amountOfPrincipalStake - _claimedPrincipalFunds;

      if (_fundsToBeDistributed >= BALANCE_CLASSIFICATION_THRESHOLD && principalStakeRemaining > 0) {
        if (_fundsToBeDistributed > principalStakeRemaining) {
          // this means there is reward part of the funds to be
          // distributed
          _principalPayout = principalStakeRemaining;
          // shouldn't underflow
          _rewardPayout = _fundsToBeDistributed - principalStakeRemaining;
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
      if (_principalPayout > 0) claimedPrincipalFunds += uint128(_principalPayout);
    }

    /// interactions

    // pay outs
    // earlier tranche recipients may try to re-enter but will cause fn to
    // revert
    // when later external calls fail (bc balance is emptied early)

    // pay out principal
    _payout(principalRecipient, _principalPayout);
    // pay out reward
    _payout(rewardRecipient, _rewardPayout);

    if (_principalPayout > 0 || _rewardPayout > 0) {
    // Write to storage
    fundsPendingWithdrawal = uint128(_memoryFundsPendingWithdrawal + _principalPayout + _rewardPayout);
    }

    emit DistributeFunds(_principalPayout, _rewardPayout);
  }

  /// Recover non-OWR tokens to a recipient
  /// @param nonOWRToken Token to recover (cannot be OWR token)
  /// @param recipient Address to receive recovered token
  function recoverFunds(address nonOWRToken, address recipient) external payable {
    /// checks

    // revert if caller tries to recover OWRecipient token
    if (nonOWRToken == token()) revert InvalidTokenRecovery_OWRToken();

    // if recoveryAddress is set, recipient must match it
    // else, recipient must be one of the OWR recipients
    address _recoveryAddress = recoveryAddress();
    if (_recoveryAddress == address(0)) {
      // ensure txn recipient is a valid OWR recipient
      (address principalRecipient, address rewardRecipient,) = getTranches();
      if (recipient != principalRecipient && recipient != rewardRecipient) {
        revert InvalidTokenRecovery_InvalidRecipient();
      }
    } else if (recipient != _recoveryAddress) {
      revert InvalidTokenRecovery_InvalidRecipient();
    }

    /// effects

    /// interactions

    // recover non-target token
    uint256 amount;
    if (nonOWRToken == ETH_ADDRESS) {
      amount = address(this).balance;
      recipient.safeTransferETH(amount);
    } else {
      amount = ERC20(nonOWRToken).balanceOf(address(this));
      nonOWRToken.safeTransfer(recipient, amount);
    }

    emit RecoverNonOWRecipientFunds(nonOWRToken, recipient, amount);
  }

  /// Withdraw token balance for account `account`
  /// @param account Address to withdraw on behalf of
  /// @param amount Amount to withdraw
  function withdraw(address account, uint256 amount) external {
    if (pullBalances[account] < amount) revert InvalidWithdrawAmount_TooLarge();
    unchecked {
      // shouldn't underflow; fundsPendingWithdrawal = sum(pullBalances)
      fundsPendingWithdrawal -= uint128(amount);
    }
    pullBalances[account] -= amount;
    
    address _token = token();
    if (_token == ETH_ADDRESS) account.safeTransferETH(amount);
    else _token.safeTransfer(account, amount);

    emit Withdrawal(account, amount);
  }

  /// -----------------------------------------------------------------------
  /// functions - view & pure
  /// -----------------------------------------------------------------------

  /// Return unpacked tranches
  /// @return principalRecipient Addres of principal recipient
  /// @return rewardRecipient Address of reward recipient
  /// @return amountOfPrincipalStake Absolute payment threshold for principal
  function getTranches()
    public
    pure
    returns (address principalRecipient, address rewardRecipient, uint256 amountOfPrincipalStake)
  {
    uint256 tranche = _getTranche(PRINCIPAL_RECIPIENT_INDEX);
    principalRecipient = address(uint160(tranche));
    amountOfPrincipalStake = tranche >> ADDRESS_BITS;

    rewardRecipient = address(uint160(_getTranche(REWARD_RECIPIENT_INDEX)));
  }

  /// Returns the balance for account `account`
  /// @param account Account to return balance for
  /// @return Account's balance OWR token
  function getPullBalance(address account) external view returns (uint256) {
    return pullBalances[account];
  }

  /// -----------------------------------------------------------------------
  /// functions - private & internal
  /// -----------------------------------------------------------------------
  function _payout(address recipient, uint256 payoutAmount) internal {
    if (payoutAmount > 0) {
        pullBalances[recipient] += payoutAmount;
    }
  }
}