// SPDX-License-Identifier: Proprietary
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IDepositContract} from "../interfaces/IDepositContract.sol";
import {IObolValidatorManager} from "../interfaces/IObolValidatorManager.sol";

/// @title ObolValidatorManager
/// @author Obol
/// @notice A maximally-composable contract that distributes payments
/// based on threshold to its recipients.
contract ObolValidatorManager is IObolValidatorManager, OwnableRoles, ReentrancyGuard {
  /// -----------------------------------------------------------------------
  /// libraries
  /// -----------------------------------------------------------------------

  using SafeTransferLib for address;

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
  uint256 public constant SET_REWARD_ROLE = 0x10;
  uint256 public constant DEPOSIT_ROLE = 0x20;

  uint256 internal constant PUSH = 0;
  uint256 internal constant PULL = 1;

  uint256 internal constant PUBLIC_KEY_LENGTH = 48;

  /// -----------------------------------------------------------------------
  /// storage - immutable
  /// -----------------------------------------------------------------------

  address public immutable consolidationSystemContract;
  address public immutable withdrawalSystemContract;
  address public immutable depositSystemContract;
  uint64 public immutable principalThreshold;

  /// -----------------------------------------------------------------------
  /// storage - mutables
  /// -----------------------------------------------------------------------

  /// Address to receive principal funds
  address public principalRecipient;

  /// Address to receive reward funds
  address public rewardRecipient;

  /// Amount of principal stake (wei)
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

  /// @inheritdoc IObolValidatorManager
  function deposit(
    bytes calldata pubkey,
    bytes calldata withdrawal_credentials,
    bytes calldata signature,
    bytes32 deposit_data_root
  ) external payable onlyOwnerOrRoles(DEPOSIT_ROLE) {
    uint256 oldAmountOfPrincipalStake = amountOfPrincipalStake;
    amountOfPrincipalStake += msg.value;
    IDepositContract(depositSystemContract).deposit{value: msg.value}(
      pubkey,
      withdrawal_credentials,
      signature,
      deposit_data_root
    );

    emit NewAmountOfPrincipalStake(amountOfPrincipalStake, oldAmountOfPrincipalStake);
  }

  /// @inheritdoc IObolValidatorManager
  function setPrincipalRecipient(address newPrincipalRecipient) external onlyOwnerOrRoles(SET_PRINCIPAL_ROLE) {
    if (newPrincipalRecipient == address(0)) {
      revert InvalidRequest_Params();
    }

    address oldPrincipalRecipient = principalRecipient;
    principalRecipient = newPrincipalRecipient;

    emit NewPrincipalRecipient(newPrincipalRecipient, oldPrincipalRecipient);
  }

  /// @inheritdoc IObolValidatorManager
  function setAmountOfPrincipalStake(uint256 newAmount) external onlyOwnerOrRoles(SET_PRINCIPAL_ROLE) {
    if (newAmount == amountOfPrincipalStake) {
      return;
    }

    uint256 oldAmount = amountOfPrincipalStake;
    amountOfPrincipalStake = newAmount;

    emit NewAmountOfPrincipalStake(newAmount, oldAmount);
  }

  /// @inheritdoc IObolValidatorManager
  function setRewardRecipient(address newRewardRecipient) external onlyOwnerOrRoles(SET_REWARD_ROLE) {
    if (newRewardRecipient == address(0)) {
      revert InvalidRequest_Params();
    }

    address oldRewardRecipient = rewardRecipient;
    rewardRecipient = newRewardRecipient;

    emit NewRewardRecipient(newRewardRecipient, oldRewardRecipient);
  }

  /// @inheritdoc IObolValidatorManager
  function distributeFunds() external nonReentrant {
    _distributeFunds(PUSH);
  }

  /// @inheritdoc IObolValidatorManager
  function distributeFundsPull() external nonReentrant {
    _distributeFunds(PULL);
  }

  /// @inheritdoc IObolValidatorManager
  function requestConsolidation(
    ConsolidationRequest[] calldata requests,
    uint256 maxFeePerConsolidation,
    address excessFeeRecipient
  ) external payable onlyOwnerOrRoles(CONSOLIDATION_ROLE) nonReentrant {
    // Check if fee exceeds maximum allowed, otherwise get fee
    uint256 fee = _validateAndReturnFee(consolidationSystemContract, maxFeePerConsolidation);

    // Calculate total number of consolidation operations
    uint256 totalNumOfConsolidationOperations = 0;
    for (uint256 i = 0; i < requests.length; i++) {
      if (requests[i].srcPubKeys.length == 0 || requests[i].srcPubKeys.length > 63) {
        revert InvalidRequest_Params();
      }
      totalNumOfConsolidationOperations += requests[i].srcPubKeys.length;
    }
    // Check if the msg.value is enough to cover the fees
    uint256 totalFeeRequired = fee * totalNumOfConsolidationOperations;
    _validateSufficientValueForFee(msg.value, totalFeeRequired);

    // Perform the consolidation requests
    for (uint256 i = 0; i < requests.length; i++) {
      _validatePubkeyLength(requests[i].targetPubKey);

      for (uint256 j = 0; j < requests[i].srcPubKeys.length; j++) {
        _validatePubkeyLength(requests[i].srcPubKeys[j]);

        // Add the consolidation request
        bytes memory callData = bytes.concat(requests[i].srcPubKeys[j], requests[i].targetPubKey);
        (bool writeOK, ) = consolidationSystemContract.call{value: fee}(callData);
        if (!writeOK) {
          revert InvalidConsolidation_Failed();
        }
        // Emit consolidation event for each operation
        emit ConsolidationRequested(msg.sender, requests[i].srcPubKeys[j], requests[i].targetPubKey, fee);
      }
    }
    // Refund any excess value back to the excessFeeRecipient
    _refundExcessFee(msg.value, totalFeeRequired, excessFeeRecipient);
  }

  /// @inheritdoc IObolValidatorManager
  function requestWithdrawal(
    bytes[] calldata pubKeys,
    uint64[] calldata amounts,
    uint256 maxFeePerWithdrawal,
    address excessFeeRecipient
  ) external payable onlyOwnerOrRoles(WITHDRAWAL_ROLE) nonReentrant {
    if (pubKeys.length != amounts.length) revert InvalidRequest_Params();

    // check if the value sent is enough to cover the fees
    uint256 maxFeePayable = maxFeePerWithdrawal * pubKeys.length;
    _validateSufficientValueForFee(msg.value, maxFeePayable);

    // Check if fee exceeds maximum allowed, otherwise get fee
    uint256 fee = _validateAndReturnFee(withdrawalSystemContract, maxFeePerWithdrawal);

    uint256 totalFeePaid = 0;
    uint256 len = pubKeys.length;

    for (uint256 i; i < len; i++) {
      _validatePubkeyLength(pubKeys[i]);

      // Add the withdrawal request
      bytes memory callData = abi.encodePacked(pubKeys[i], amounts[i]);
      (bool writeOK, ) = withdrawalSystemContract.call{value: fee}(callData);
      if (!writeOK) {
        revert InvalidWithdrawal_Failed();
      }
      totalFeePaid += fee;

      // Emit withdrawal event for each validator
      emit WithdrawalRequested(msg.sender, pubKeys[i], amounts[i], fee);
    }

    // Refund any excess value back to the excessFeeRecipient
    _refundExcessFee(msg.value, totalFeePaid, excessFeeRecipient);
  }

  /// @inheritdoc IObolValidatorManager
  function recoverFunds(address nonOVMToken, address recipient) external onlyOwnerOrRoles(RECOVER_FUNDS_ROLE) {
    uint256 amount = ERC20(nonOVMToken).balanceOf(address(this));
    nonOVMToken.safeTransfer(recipient, amount);

    emit RecoverNonOVMFunds(nonOVMToken, recipient, amount);
  }

  /// @inheritdoc IObolValidatorManager
  function withdraw(address account) external {
    uint256 amount = pullBalances[account];
    if (amount == 0) {
      return;
    }

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

  /// @inheritdoc IObolValidatorManager
  function getPullBalance(address account) external view returns (uint256) {
    return pullBalances[account];
  }

  /// -----------------------------------------------------------------------
  /// OwnableRoles function overrides
  /// -----------------------------------------------------------------------

  /// @inheritdoc IObolValidatorManager
  function grantRoles(address user, uint256 roles) public payable override(IObolValidatorManager, OwnableRoles) {
    super.grantRoles(user, roles);
  }

  /// @inheritdoc IObolValidatorManager
  function revokeRoles(address user, uint256 roles) public payable override(IObolValidatorManager, OwnableRoles) {
    super.revokeRoles(user, roles);
  }

  /// @inheritdoc IObolValidatorManager
  function renounceRoles(uint256 roles) public payable override(IObolValidatorManager, OwnableRoles) {
    super.renounceRoles(roles);
  }

  /// @inheritdoc IObolValidatorManager
  function rolesOf(address user) public view override(IObolValidatorManager, OwnableRoles) returns (uint256 roles) {
    return super.rolesOf(user);
  }

  /// @inheritdoc IObolValidatorManager
  function hasAnyRole(
    address user,
    uint256 roles
  ) public view override(IObolValidatorManager, OwnableRoles) returns (bool) {
    return super.hasAnyRole(user, roles);
  }

  /// @inheritdoc IObolValidatorManager
  function hasAllRoles(
    address user,
    uint256 roles
  ) public view override(IObolValidatorManager, OwnableRoles) returns (bool) {
    return super.hasAllRoles(user, roles);
  }

  /// @inheritdoc IObolValidatorManager
  function transferOwnership(address newOwner) public payable override(IObolValidatorManager, Ownable) {
    super.transferOwnership(newOwner);
  }

  /// @inheritdoc IObolValidatorManager
  function renounceOwnership() public payable override(IObolValidatorManager, Ownable) {
    super.renounceOwnership();
  }

  /// @inheritdoc IObolValidatorManager
  function requestOwnershipHandover() public payable override(IObolValidatorManager, Ownable) {
    super.requestOwnershipHandover();
  }

  /// @inheritdoc IObolValidatorManager
  function cancelOwnershipHandover() public payable override(IObolValidatorManager, Ownable) {
    super.cancelOwnershipHandover();
  }

  /// @inheritdoc IObolValidatorManager
  function completeOwnershipHandover(address pendingOwner) public payable override(IObolValidatorManager, Ownable) {
    super.completeOwnershipHandover(pendingOwner);
  }

  /// @inheritdoc IObolValidatorManager
  function owner() public view override(IObolValidatorManager, Ownable) returns (address result) {
    return super.owner();
  }

  /// @inheritdoc IObolValidatorManager
  function ownershipHandoverExpiresAt(
    address pendingOwner
  ) public view override(IObolValidatorManager, Ownable) returns (uint256 result) {
    return super.ownershipHandoverExpiresAt(pendingOwner);
  }

  /// -----------------------------------------------------------------------
  /// functions - private & internal
  /// -----------------------------------------------------------------------

  /// Internal function to validate the caller sent sufficient value for fee. Used for pectra related operations.
  /// @param value The value.
  /// @param totalFee The total fee.
  function _validateSufficientValueForFee(uint256 value, uint256 totalFee) internal pure {
    if (value < totalFee) {
      revert InvalidRequest_NotEnoughFee();
    }
  }

  /// Internal function to validate the fee. Used for pectra related operations.
  /// @param feeContract The address of the fee contract.
  /// @param maxAllowedFee The maximum allowed fee.
  /// @return fee The fee.
  /// @dev Reverts if the fee is higher than the maximum allowed fee, or if the fee read fails.
  function _validateAndReturnFee(address feeContract, uint256 maxAllowedFee) internal view returns (uint256 fee) {
    // Read current fee from the contract
    (bool readOK, bytes memory feeData) = feeContract.staticcall("");
    if (!readOK) {
      revert InvalidRequest_SystemGetFee();
    }
    fee = uint256(bytes32(feeData));

    if (fee > maxAllowedFee) {
      revert InvalidRequest_NotEnoughFee();
    }
  }

  /// Internal function to validate that a public key is exactly 48 bytes in length
  /// @param pubkey The public key to validate
  function _validatePubkeyLength(bytes memory pubkey) internal pure {
    if (pubkey.length != 48) {
      revert InvalidRequest_Params();
    }
  }

  /// Internal function to refund the excess fee for pectra related operations.
  /// @param _totalValueReceived The total value received.
  /// @param _totalFeePaid The total fee paid.
  /// @param _excessFeeRecipient The address of the excess fee recipient.
  function _refundExcessFee(uint256 _totalValueReceived, uint256 _totalFeePaid, address _excessFeeRecipient) internal {
    // send excess value back to _excessFeeRecipient
    if (_totalValueReceived > _totalFeePaid) {
      (bool success, ) = payable(_excessFeeRecipient).call{value: _totalValueReceived - _totalFeePaid}("");
      if (!success) {
        emit UnsentExcessFee(_excessFeeRecipient, _totalValueReceived - _totalFeePaid);
      }
    }
  }

  /// Compute system contract's fee
  /// @param systemContractAddress Address of the consolidation system contract
  /// @return The computed fee
  function _computeSystemContractFee(address systemContractAddress) internal view returns (uint256) {
    (bool ok, bytes memory result) = systemContractAddress.staticcall("");
    if (!ok) revert InvalidRequest_SystemGetFee();

    return uint256(bytes32(result));
  }

  /// Distributes target token inside the contract to next-in-line recipients
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
      if (_principalPayout > 0) {
        amountOfPrincipalStake -= uint128(_principalPayout);
        emit NewAmountOfPrincipalStake(amountOfPrincipalStake, amountOfPrincipalStake + _principalPayout);
      }
    }

    /// interactions

    // pay outs
    // earlier tranche recipients may try to re-enter but will cause fn to
    // revert
    // when later external calls fail (bc balance is emptied early)

    if (pullOrPush == PULL) {
      if (_principalPayout > 0 || _rewardPayout > 0) {
        // Write to storage
        fundsPendingWithdrawal = uint128(_memoryFundsPendingWithdrawal + _principalPayout + _rewardPayout);
      }
    }

    // pay out principal
    _payout(principalRecipient, _principalPayout, pullOrPush);
    // pay out reward
    _payout(rewardRecipient, _rewardPayout, pullOrPush);

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
