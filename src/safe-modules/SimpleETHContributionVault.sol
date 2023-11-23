// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IETH2DepositContract} from "../interfaces/IETH2DepositContract.sol";

contract SimpleETHContributionVault {
  using SafeTransferLib for address;

  /// @notice unathorised user
  /// @param user address of unauthorized user
  error Unauthorized(address user);

  /// @notice cannot rage quit
  error CannotRageQuit();

  /// @notice incomplete contribution
  error IncompleteContribution(uint256 actual, uint256 expected);

  /// @notice Amount of ETH validator stake
  uint256 internal constant ETH_STAKE = 32 ether;

  event Deposit(address to, uint256 amount);

  event DepositValidator(
    bytes[] pubkeys, bytes[] withdrawal_credentials, bytes[] signatures, bytes32[] deposit_data_roots
  );
  event RageQuit(address to, uint256 amount);
  event RescueFunds(uint256 amount);

  /// @notice
  mapping(address => uint256) public userBalances;

  IETH2DepositContract public immutable depositContract;

  address public immutable safe;

  bool public activated;

  modifier onlySafe() {
    if (msg.sender != safe) revert Unauthorized(msg.sender);
    _;
  }

  constructor(address _safe, address eth2DepositContract) {
    safe = _safe;
    depositContract = IETH2DepositContract(eth2DepositContract);
  }

  receive() external payable {
    _deposit(msg.sender, msg.value);
  }

  /// Deposit ETH into ETH2 deposit contract
  /// @param pubkeys Array of validator pub keys
  /// @param withdrawal_credentials Array of validator withdrawal credentials
  /// @param signatures Array of validator signatures
  /// @param deposit_data_roots Array of validator deposit data roots
  function depositValidator(
    bytes[] calldata pubkeys,
    bytes[] calldata withdrawal_credentials,
    bytes[] calldata signatures,
    bytes32[] calldata deposit_data_roots
  ) external payable onlySafe {
    uint256 size = pubkeys.length;

    if (address(this).balance < size * ETH_STAKE) {
      revert IncompleteContribution(address(this).balance, ETH_STAKE * size);
    }

    for (uint256 i = 0; i < size;) {
      depositContract.deposit{value: ETH_STAKE}(
        pubkeys[i], withdrawal_credentials[i], signatures[i], deposit_data_roots[i]
      );

      unchecked {
        i++;
      }
    }

    activated = true;

    emit DepositValidator(pubkeys, withdrawal_credentials, signatures, deposit_data_roots);
  }

  /// Exit contribution vault prior to deposit starts
  /// It allows a contributor to exit the vault before the validators are
  /// activated
  /// @param to Address to send funds to
  /// @param amount balance to withdraw
  function rageQuit(address to, uint256 amount) external {
    if (activated == true) revert CannotRageQuit();

    userBalances[msg.sender] -= amount;
    to.safeTransferETH(amount);

    emit RageQuit(to, amount);
  }

  /// Rescue non-ETH tokens stuck to the safe
  /// @param token Token address
  /// @param amount amount of balance to transfer to Safe
  function rescueFunds(address token, uint256 amount) external {
    token.safeTransfer(safe, amount);
    emit RescueFunds(amount);
  }

  function _deposit(address to, uint256 amount) internal {
    userBalances[to] += amount;
    emit Deposit(to, amount);
  }
}
