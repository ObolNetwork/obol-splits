// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {SymPodSlasher} from "src/symbiotic/SymPodSlasher.sol";
import {BaseSymPodHarnessTest} from "./SymPod.t.sol";
import "forge-std/Test.sol";

contract SymPodSlasherTest is BaseSymPodHarnessTest {
  SymPodSlasher createdSlasher;

  function setUp() public override {
    super.setUp();
    createdSlasher = new SymPodSlasher();
  }

  function test_triggerWithdrawal() external {
    // I need to init the onSlash function
  }

  function test_triggerBurn() external {}
}
