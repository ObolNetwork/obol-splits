// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {SymPodSlasher} from "src/symbiotic/SymPodSlasher.sol";
import {BaseSymPodTest, BaseSymPodHarnessTest} from "./SymPod.t.sol";
import "forge-std/Test.sol";

contract SymPodSlasherTest is BaseSymPodHarnessTest {
  event TriggerWithdrawal(address sender, address symPod, uint256 sharesToBurn, bytes32 withdrawalKey);

  event TriggerBurn(address sender, address symPod, uint256 amountBurned, bytes32 withdrawalKey);

  SymPodSlasher createdSlasher;

  address user1;

  function setUp() public override {
    super.setUp();
    createdSlasher = SymPodSlasher(payable(slasher));
    user1 = makeAddr("user1");
  }

  function testFuzz_CanReceiveETH(uint256 amount) external {
    vm.assume(amount > 0);
    amount = bound(amount, 1 gwei, type(uint96).max);

    vm.deal(address(this), amount);

    payable(address(createdSlasher)).transfer(amount);

    assertEq(address(createdSlasher).balance, amount, "invalid eth balance");
  }

  function testFuzz_triggerWithdrawal(uint256 amountOfShares) external {
    vm.assume(amountOfShares > 0);
    amountOfShares = roundDown(bound(amountOfShares, 1 gwei, type(uint96).max));
    createdHarnessPod.mintSharesPlusAssetsAndRestakedPodWei(amountOfShares, address(slasher));

    vm.expectEmit(true, true, true, false);
    emit TriggerWithdrawal(address(this), address(createdHarnessPod), amountOfShares, bytes32(0));

    createdSlasher.triggerWithdrawal(createdHarnessPod);
  }

  function testFuzz_triggerBurn(uint256 amountOfShares) external {
    vm.assume(amountOfShares > 0);
    amountOfShares = roundDown(bound(amountOfShares, 1 gwei, type(uint96).max));
    createdHarnessPod.mintSharesPlusAssetsAndRestakedPodWei(amountOfShares, address(slasher));

    vm.deal(address(createdHarnessPod), amountOfShares);

    bytes32 withdrawalKey = createdSlasher.triggerWithdrawal(createdHarnessPod);

    vm.expectEmit(true, true, true, false);
    emit TriggerBurn(address(this), address(createdHarnessPod), 0, withdrawalKey);
    createdSlasher.triggerBurn(createdHarnessPod, withdrawalKey);
  }
}
