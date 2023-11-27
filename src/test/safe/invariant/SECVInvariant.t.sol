// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {SimpleETHContributionVault} from "src/safe-modules/SimpleETHContributionVault.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {getETHValidatorData} from "../SimpleETHContributionVault.t.sol";

contract MockDepositContract {
  uint256 public ghost_depositSum;

  event Deposit(bytes[] pubkeys, bytes[] withdrawal_credentials, bytes[] signatures, bytes32[] deposit_data_roots);

  function deposit(bytes[] calldata, bytes[] calldata, bytes[] calldata, bytes32[] calldata) external payable {
    ghost_depositSum += msg.value;
  }
}

contract SECVMock is SimpleETHContributionVault {
  constructor(address _safe, address eth2DepositContract) SimpleETHContributionVault(_safe, eth2DepositContract) {}

  /// @notice Mock depositValidator function
  function depositValidatorMock(
    bytes[] calldata pubkeys,
    bytes[] calldata withdrawal_credentials,
    bytes[] calldata signatures,
    bytes32[] calldata deposit_data_roots
  ) external payable {
    for (uint256 i = 0; i < 1;) {
      depositContract.deposit{value: msg.value}(
        pubkeys[i], withdrawal_credentials[i], signatures[i], deposit_data_roots[i]
      );
      unchecked {
        i++;
      }
    }
  }
}

contract SECVBoundedHandler is CommonBase, StdCheats, StdUtils {
  SECVMock public contributionVault;

  uint256 public constant ETH_SUPPLY = 1_000_000 ether;

  uint256 public ghost_depositSum;
  uint256 public ghost_rageQuitSum;

  receive() external payable {}

  constructor(SECVMock vault) {
    contributionVault = vault;
    deal(address(this), ETH_SUPPLY);
  }

  function deposit(uint256 amount) external payable {
    amount = bound(amount, 0, address(this).balance);
    (bool _success,) = payable(contributionVault).call{value: amount}("");
    assert(_success);

    ghost_depositSum += amount;
  }

  function rageQuit(uint256 amount) external payable {
    amount = bound(amount, 0, contributionVault.userBalances(address(this)));
    contributionVault.rageQuit(address(this), amount);

    ghost_rageQuitSum += amount;
  }

  function depositValidator(uint256 amount) external payable {
    amount = bound(amount, 0, address(contributionVault).balance);
    (
      bytes[] memory pubkeys,
      bytes[] memory withdrawal_credentials,
      bytes[] memory signatures,
      bytes32[] memory deposit_data_roots
    ) = getETHValidatorData();

    contributionVault.depositValidatorMock{value: amount}(
      pubkeys, withdrawal_credentials, signatures, deposit_data_roots
    );
  }
}

contract SECVInvariant is Test {
  MockDepositContract public mockDepositContract;
  SECVMock public contributionVault;
  SECVBoundedHandler public handler;

  address public safe;

  function setUp() public {
    safe = makeAddr("safe");

    mockDepositContract = new MockDepositContract();
    contributionVault = new SECVMock(
            safe,
            address(mockDepositContract)
        );
    handler = new SECVBoundedHandler(contributionVault);

    targetContract(address(handler));
  }

  /// @notice This invariant checks that the sum of balances in the handler,
  /// vault and mock deposit contract is equal
  function invariant_balanceEqual() public {
    assertEq(
      handler.ETH_SUPPLY(),
      address(handler).balance + contributionVault.userBalances(address(handler)) + address(mockDepositContract).balance
    );
  }

  /// @notice This invariant checks that the vault is
  /// always solvent when a user ragequits.
  function invariant_vaultIsSolvent() public {
    assertEq(
      address(contributionVault).balance,
      handler.ghost_depositSum() + mockDepositContract.ghost_depositSum() - handler.ghost_rageQuitSum()
    );
  }
}
