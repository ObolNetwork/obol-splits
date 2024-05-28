// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {Clone} from "solady/utils/Clone.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/// @title OptimisticWithdrawalRecipient
/// @author Obol
/// @notice A maximally-composable contract that distributes payments
/// based on threshold to it's recipients
/// @dev Only ETH can be distributed for a given deployment. There is a
/// recovery method for tokens sent by accident.
contract OptimisticWithdrawalRecipient is Clone {
  /// -----------------------------------------------------------------------
  /// libraries
  /// -----------------------------------------------------------------------

  using SafeTransferLib for address;

  /// -----------------------------------------------------------------------
  /// errors
  /// -----------------------------------------------------------------------

  /// Invalid token recovery recipient
  error InvalidTokenRecovery_InvalidRecipient();

  /// Invalid distribution
  error InvalidDistribution_TooLarge();

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
  /// @param pullFlowFlag Flag for pushing funds to recipients or storing for
  /// pulling
  event DistributeFunds(uint256 principalPayout, uint256 rewardPayout, uint256 pullFlowFlag);

  /// Emitted after tokens are recovered to a recipient
  /// @param recoveryAddressToken Recovered token (cannot be
  /// ETH)
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

  uint256 internal constant PUSH = 0;
  uint256 internal constant PULL = 1;

  uint256 internal constant ONE_WORD = 32;
  uint256 internal constant ADDRESS_BITS = 160;

  /// @dev threshold for pushing balance update as reward or principal
  uint256 internal constant BALANCE_CLASSIFICATION_THRESHOLD = 16 ether;
  uint256 internal constant PRINCIPAL_RECIPIENT_INDEX = 0;
  uint256 internal constant REWARD_RECIPIENT_INDEX = 1;

  /// -----------------------------------------------------------------------
  /// storage - cwia offsets
  /// -----------------------------------------------------------------------

  // recoveryAddress (address, 20 bytes),
  // tranches (uint256[], numTranches * 32 bytes)

  // 0; first item
  uint256 internal constant RECOVERY_ADDRESS_OFFSET = 0;
  // 20 = recoveryAddress_offset (0) + recoveryAddress_size (address, 20
  // bytes)
  uint256 internal constant TRANCHES_OFFSET = 20;

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
    _distributeFunds(PUSH);
  }

  /// Distributes target token inside the contract to recipients
  /// @dev backup recovery if any recipient tries to brick the OWRecipient for
  /// remaining recipients
  function distributeFundsPull() external payable {
    _distributeFunds(PULL);
  }

  /// Recover non-OWR tokens to a recipient
  /// @param nonOWRToken Token to recover (cannot be OWR token)
  /// @param recipient Address to receive recovered token
  function recoverFunds(address nonOWRToken, address recipient) external payable {
    /// checks

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
    uint256 amount = ERC20(nonOWRToken).balanceOf(address(this));
    nonOWRToken.safeTransfer(recipient, amount);

    emit RecoverNonOWRecipientFunds(nonOWRToken, recipient, amount);
  }

  /// Withdraw token balance for account `account`
  /// @param account Address to withdraw on behalf of
  function withdraw(address account) external {
    uint256 tokenAmount = pullBalances[account];
    unchecked {
      // shouldn't underflow; fundsPendingWithdrawal = sum(pullBalances)
      fundsPendingWithdrawal -= uint128(tokenAmount);
    }
    pullBalances[account] = 0;
    account.safeTransferETH(tokenAmount);

    emit Withdrawal(account, tokenAmount);
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

  /// Distributes target token inside the contract to next-in-line recipients
  /// @dev can PUSH or PULL funds to recipients
  function _distributeFunds(uint256 pullFlowFlag) internal {
    /// checks

    /// effects

    // load storage into memory
    uint256 currentbalance = address(this).balance;
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
    _payout(principalRecipient, _principalPayout, pullFlowFlag);
    // pay out reward
    _payout(rewardRecipient, _rewardPayout, pullFlowFlag);

    if (pullFlowFlag == PULL) {
      if (_principalPayout > 0 || _rewardPayout > 0) {
        // Write to storage
        fundsPendingWithdrawal = uint128(_memoryFundsPendingWithdrawal + _principalPayout + _rewardPayout);
      }
    }

    emit DistributeFunds(_principalPayout, _rewardPayout, pullFlowFlag);
  }

  function _payout(address recipient, uint256 payoutAmount, uint256 pullFlowFlag) internal {
    if (payoutAmount > 0) {
      if (pullFlowFlag == PULL) {
        // Write to Storage
        pullBalances[recipient] += payoutAmount;
      } else {
        recipient.safeTransferETH(payoutAmount);
      }
    }
  }
}
