// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {SymTest} from "halmos/SymTest.sol";
import {SymPod} from "src/symbiotic/SymPod.sol";
import {MockBeaconRootOracle} from "src/test/utils/mocks/MockBeaconRootOracle.sol";
import {MockERC20} from "src/test/utils/mocks/MockERC20.sol";
import {MockETH2Deposit} from "src/test/utils/mocks/MockETH2Deposit.sol";
import {SymPodConfigurator} from "src/symbiotic/SymPodConfigurator.sol";

contract SymPodSymbolic is SymPod {
  constructor(
    address _symPodConfigurator,
    address _eth2DepositContract,
    address _beaconRootsOracle,
    uint256 _withdrawDelayPeriod,
    uint256 _balanceDelta
  ) SymPod(_symPodConfigurator, _eth2DepositContract, _beaconRootsOracle, _withdrawDelayPeriod, _balanceDelta) {}

  /// @dev Generate withdrawal key
  function _getWithdrawalKey(uint256, uint256) internal pure override returns (bytes32 withdrawalKey) {
    withdrawalKey = bytes32("1");
  }
}

/// @custom:halmos --storage-layout=generic --solver-timeout-assertion 0
contract SymPodHalmostTest is SymTest, Test {
  address admin;
  address slasher;
  address withrawalAddress;
  address recoveryRecipient;

  SymPodSymbolic symPod;

  MockETH2Deposit eth2Deposit;
  MockBeaconRootOracle beaconRootsOracle;

  bytes32 blockRoot;

  /**
   *
   * Function for symbolic tests using eth balance only
   *
   * 1. startCheckpoint
   * 2. initWithdraw
   * 3. completeWithdraw
   * 4. onSlash
   */
  function setUp() public {
    vm.warp(1_000_000);

    admin = address(0xbeef);
    slasher = address(0x10);
    withrawalAddress = address(0x11);
    recoveryRecipient = address(0x12);

    address configurator = address(new SymPodConfigurator(admin));

    eth2Deposit = new MockETH2Deposit();
    beaconRootsOracle = new MockBeaconRootOracle();

    symPod = new SymPodSymbolic(configurator, address(eth2Deposit), address(beaconRootsOracle), 1, 0);

    symPod.initialize("DEMO", "DEMO", slasher, admin, withrawalAddress, recoveryRecipient);

    // set roots on oracle
    blockRoot = bytes32(uint256(1));
    beaconRootsOracle.setBlockRoot(uint64(block.timestamp), blockRoot);
  }

  function check_startCP_balanceIncrease(uint256 amountOfEther, bool revertIfNoBalance) external {
    vm.assume(amountOfEther > 0);

    vm.deal(address(symPod), amountOfEther);

    vm.prank(admin);
    symPod.startCheckpoint(revertIfNoBalance);

    uint256 roundToNearestGwei = roundDown(amountOfEther);

    assert(symPod.balanceOf(admin) == roundToNearestGwei);
  }

  // Note: This takes quite a long time to run
  function check_startCP_InitWithdraw_CompleteWithdraw(
    bool revertIfNoBalance,
    uint256 nonce,
    uint256 amountOfEther,
    uint256 amountToWithdraw
  ) external {
    amountOfEther = roundDown(amountOfEther);
    amountToWithdraw = roundDown(amountToWithdraw);

    vm.assume(amountOfEther > 1 gwei);
    vm.assume(amountToWithdraw > 0);
    // just to keep solver within reasonable bounds
    vm.assume(amountToWithdraw <= amountOfEther);

    vm.deal(address(symPod), amountOfEther);
    vm.prank(admin);
    symPod.startCheckpoint(revertIfNoBalance);

    vm.prank(admin);
    bytes32 withdrawalKey = symPod.initWithdraw(amountToWithdraw, nonce);

    uint256 pendingAmountToWithdrawWei = symPod.pendingAmountToWithdrawWei();

    assert(pendingAmountToWithdrawWei == amountToWithdraw);
    // pass the withdrawal delay
    vm.warp(block.timestamp + 10 seconds);
    // complete withdraw
    uint256 amountReceived = symPod.completeWithdraw(withdrawalKey);
    assert(amountReceived == amountToWithdraw);
  }

  function check_startCP_OnSlash_CompleteWithdraw(bool revertIfNoBalance, uint64 amountOfEther, uint64 amountToSlash)
    external
  {
    vm.assume(amountOfEther > 0);
    vm.assume(amountToSlash > 0);

    vm.deal(address(symPod), amountOfEther);
    vm.prank(admin);
    symPod.startCheckpoint(revertIfNoBalance);

    // transfer an amount to the slasher
    vm.prank(admin);
    symPod.transfer(slasher, amountToSlash);

    // slash
    vm.prank(slasher);
    bytes32 withdrawalKey = symPod.onSlash(amountToSlash);

    uint256 amountReceived = symPod.completeWithdraw(withdrawalKey);

    assert(amountReceived == amountToSlash);
  }
  function roundDown(uint256 x) public pure returns (uint256 y) {
    y = (x / 1 gwei) * 1 gwei;
  }
}
