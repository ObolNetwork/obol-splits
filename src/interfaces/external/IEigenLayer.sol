// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";

interface IEigenLayerUtils {
  // @notice Struct that bundles together a signature and an expiration time for the signature. Used primarily for stack
  // management.
  struct SignatureWithExpiry {
    // the signature itself, formatted as a single bytes object
    bytes signature;
    // the expiration timestamp (UTC) of the signature
    uint256 expiry;
  }

  // @notice Struct that bundles together a signature, a salt for uniqueness, and an expiration time for the signature.
  // Used primarily for stack management.
  struct SignatureWithSaltAndExpiry {
    // the signature itself, formatted as a single bytes object
    bytes signature;
    // the salt used to generate the signature
    bytes32 salt;
    // the expiration timestamp (UTC) of the signature
    uint256 expiry;
  }
}

interface IDelegationManager is IEigenLayerUtils {
  /**
   * @notice Caller delegates their stake to an operator.
   * @param operator The account (`msg.sender`) is delegating its assets to for use in serving applications built on
   * EigenLayer.
   * @param approverSignatureAndExpiry Verifies the operator approves of this delegation
   * @param approverSalt A unique single use value tied to an individual signature.
   * @dev The approverSignatureAndExpiry is used in the event that:
   *          1) the operator's `delegationApprover` address is set to a non-zero value.
   *                  AND
   *          2) neither the operator nor their `delegationApprover` is the `msg.sender`, since in the event that the
   * operator
   *             or their delegationApprover is the `msg.sender`, then approval is assumed.
   * @dev In the event that `approverSignatureAndExpiry` is not checked, its content is ignored entirely; it's
   * recommended to use an empty input
   * in this case to save on complexity + gas costs
   */
  function delegateTo(address operator, SignatureWithExpiry memory approverSignatureAndExpiry, bytes32 approverSalt)
    external;

  /**
   * @notice Undelegates the staker from the operator who they are delegated to. Puts the staker into the "undelegation
   * limbo" mode of the EigenPodManager
   * and queues a withdrawal of all of the staker's shares in the StrategyManager (to the staker), if necessary.
   * @param staker The account to be undelegated.
   * @return withdrawalRoot The root of the newly queued withdrawal, if a withdrawal was queued. Otherwise just
   * bytes32(0).
   *
   * @dev Reverts if the `staker` is also an operator, since operators are not allowed to undelegate from themselves.
   * @dev Reverts if the caller is not the staker, nor the operator who the staker is delegated to, nor the operator's
   * specified "delegationApprover"
   * @dev Reverts if the `staker` is already undelegated.
   */
  function undelegate(address staker) external returns (bytes32 withdrawalRoot);
}

interface IEigenPodManager {
  /**
   * @notice Creates an EigenPod for the sender.
   * @dev Function will revert if the `msg.sender` already has an EigenPod.
   * @dev Returns EigenPod address
   */
  function createPod() external returns (address);

  /**
   * @notice Stakes for a new beacon chain validator on the sender's EigenPod.
   * Also creates an EigenPod for the sender if they don't have one already.
   * @param pubkey The 48 bytes public key of the beacon chain validator.
   * @param signature The validator's signature of the deposit data.
   * @param depositDataRoot The root/hash of the deposit data for the validator's deposit.
   */
  function stake(bytes calldata pubkey, bytes calldata signature, bytes32 depositDataRoot) external payable;

  /// @notice Returns the address of the `podOwner`'s EigenPod (whether it is deployed yet or not).
  function getPod(address podOwner) external returns (address);
}

interface IDelayedWithdrawalRouter {
  /**
   * @notice Called in order to withdraw delayed withdrawals made to the `recipient` that have passed the
   * `withdrawalDelayBlocks` period.
   * @param recipient The address to claim delayedWithdrawals for.
   * @param maxNumberOfDelayedWithdrawalsToClaim Used to limit the maximum number of delayedWithdrawals to loop through
   * claiming.
   * @dev
   *      WARNING: Note that the caller of this function cannot control where the funds are sent, but they can control
   * when the
   *              funds are sent once the withdrawal becomes claimable.
   */
  function claimDelayedWithdrawals(address recipient, uint256 maxNumberOfDelayedWithdrawalsToClaim) external;

  /**
   * @notice Creates a delayed withdrawal for `msg.value` to the `recipient`.
   * @dev Only callable by the `podOwner`'s EigenPod contract.
   */
  function createDelayedWithdrawal(address podOwner, address recipient) external;

  /// @notice Owner-only function for modifying the value of the `withdrawalDelayBlocks` variable.
  function setWithdrawalDelayBlocks(uint256 newValue) external;
}

interface IEigenPod {
  function activateRestaking() external;

  /// @notice Called by the pod owner to withdraw the balance of the pod when `hasRestaked` is set to false
  function withdrawBeforeRestaking() external;

  /// @notice Called by the pod owner to withdraw the nonBeaconChainETHBalanceWei
  function withdrawNonBeaconChainETHBalanceWei(address recipient, uint256 amountToWithdraw) external;

  /// @notice called by owner of a pod to remove any ERC20s deposited in the pod
  function recoverTokens(ERC20[] memory tokenList, uint256[] memory amountsToWithdraw, address recipient) external;

  /// @notice The single EigenPodManager for EigenLayer
  function eigenPodManager() external view returns (IEigenPodManager);

  /// @notice The owner of this EigenPod
  function podOwner() external view returns (address);

  /// @notice an indicator of whether or not the podOwner has ever "fully restaked" by successfully calling
  /// `verifyCorrectWithdrawalCredentials`.
  function hasRestaked() external view returns (bool);

  /// @notice The max amount of eth, in gwei, that can be restaked per validator
  function MAX_RESTAKED_BALANCE_GWEI_PER_VALIDATOR() external view returns (uint64);

  /// @notice the amount of execution layer ETH in this contract that is staked in EigenLayer (i.e. withdrawn from
  /// beaconchain but not EigenLayer),
  function withdrawableRestakedExecutionLayerGwei() external view returns (uint64);

  /// @notice any ETH deposited into the EigenPod contract via the `receive` fallback function
  function nonBeaconChainETHBalanceWei() external view returns (uint256);

  /// @notice Used to initialize the pointers to contracts crucial to the pod's functionality, in beacon proxy
  /// construction from EigenPodManager
  function initialize(address owner) external;

  /// @notice Called by EigenPodManager when the owner wants to create another ETH validator.
  function stake(bytes calldata pubkey, bytes calldata signature, bytes32 depositDataRoot) external payable;
}
