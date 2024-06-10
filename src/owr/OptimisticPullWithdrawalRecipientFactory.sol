// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {OptimisticPullWithdrawalRecipient} from "./OptimisticPullWithdrawalRecipient.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {IENSReverseRegistrar} from "../interfaces/external/IENSReverseRegistrar.sol";

/// @title OptimisticPullWithdrawalRecipientFactory
/// @author Obol
/// @notice A factory contract for cheaply deploying
/// OptimisticPullWithdrawalRecipient.
/// @dev This contract uses token = address(0) to refer to ETH.
contract OptimisticPullWithdrawalRecipientFactory {
  /// -----------------------------------------------------------------------
  /// errors
  /// -----------------------------------------------------------------------

  /// Invalid token
  error Invalid_Token();

  /// Invalid number of recipients, must be 2
  error Invalid__Recipients();

  /// Thresholds must be positive
  error Invalid__ZeroThreshold();

  /// Invalid threshold at `index`; must be < 2^96
  /// @param threshold threshold of too-large threshold
  error Invalid__ThresholdTooLarge(uint256 threshold);

  /// -----------------------------------------------------------------------
  /// libraries
  /// -----------------------------------------------------------------------

  using LibClone for address;

  /// -----------------------------------------------------------------------
  /// events
  /// -----------------------------------------------------------------------

  /// Emitted after a new OptimisticPullWithdrawalRecipient module is deployed
  /// @param owr Address of newly created OptimisticPullWithdrawalRecipient clone
  /// @param token Address of ERC20 to distribute (0x0 used for ETH)
  /// @param recoveryAddress Address to recover non-OWR tokens to
  /// @param principalRecipient Address to distribute principal payment to
  /// @param rewardRecipient Address to distribute reward payment to
  /// @param threshold Absolute payment threshold for OWR first recipient
  /// (reward recipient has no threshold & receives all residual flows)
  event CreateOWRecipient(
    address indexed owr, address token, address recoveryAddress, address principalRecipient, address rewardRecipient, uint256 threshold
  );

  /// -----------------------------------------------------------------------
  /// storage
  /// -----------------------------------------------------------------------

  uint256 internal constant ADDRESS_BITS = 160;

  /// OptimisticWithdrawalRecipient implementation address
  OptimisticPullWithdrawalRecipient public immutable owrImpl;

  /// -----------------------------------------------------------------------
  /// constructor
  /// -----------------------------------------------------------------------

  constructor(
    string memory _ensName,
    address _ensReverseRegistrar,
    address _ensOwner
  ) {
    owrImpl = new OptimisticPullWithdrawalRecipient();
    IENSReverseRegistrar(_ensReverseRegistrar).setName(_ensName);
    IENSReverseRegistrar(_ensReverseRegistrar).claim(_ensOwner);
  }

  /// -----------------------------------------------------------------------
  /// functions
  /// -----------------------------------------------------------------------

  /// -----------------------------------------------------------------------
  /// functions - public & external
  /// -----------------------------------------------------------------------

  /// Create a new OptimisticWithdrawalRecipient clone
  /// @param token Address of ERC20 to distribute (0x0 used for ETH)
  /// @param recoveryAddress Address to recover tokens to
  /// If this address is 0x0, recovery of unrelated tokens can be completed by
  /// either the principal or reward recipients.  If this address is set, only
  /// this address can recover
  /// tokens (or ether) that isn't the token of the OWRecipient contract
  /// @param principalRecipient Address to distribute principal payments to
  /// @param rewardRecipient Address to distribute reward payments to
  /// @param amountOfPrincipalStake Absolute amount of stake to be paid to
  /// principal recipient (multiple of 32 ETH)
  /// (reward recipient has no threshold & receives all residual flows)
  /// it cannot be greater than uint96
  /// @return owr Address of new OptimisticWithdrawalRecipient clone
  function createOWRecipient(
    address token,
    address recoveryAddress,
    address principalRecipient,
    address rewardRecipient,
    uint256 amountOfPrincipalStake
  ) external returns (OptimisticPullWithdrawalRecipient owr) {
    /// checks

    // ensure doesn't have address(0)
    if (principalRecipient == address(0) || rewardRecipient == address(0)) revert Invalid__Recipients();
    // ensure threshold isn't zero
    if (amountOfPrincipalStake == 0) revert Invalid__ZeroThreshold();
    // ensure threshold isn't too large
    if (amountOfPrincipalStake > type(uint96).max) revert Invalid__ThresholdTooLarge(amountOfPrincipalStake);

    /// effects
    uint256 principalData = (amountOfPrincipalStake << ADDRESS_BITS) | uint256(uint160(principalRecipient));
    uint256 rewardData = uint256(uint160(rewardRecipient));

    // would not exceed contract size limits
    // important to not reorder
    bytes memory data = abi.encodePacked(token, recoveryAddress, principalData, rewardData);
    owr = OptimisticPullWithdrawalRecipient(address(owrImpl).clone(data));

    emit CreateOWRecipient(address(owr), token, recoveryAddress, principalRecipient, rewardRecipient, amountOfPrincipalStake);
  }
}