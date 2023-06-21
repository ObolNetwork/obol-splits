// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import {SplitMainV2} from "src/splitter/SplitMainV2.sol";
import {SplitWallet} from "src/splitter/SplitWallet.sol";

contract SplitMainV2Test is Test {
  SplitMainV2 public splitMainV2;
  SplitWallet public splitWallet;

  function setUp() public {
    splitMainV2 = new SplitMainV2();
    splitWallet = new SplitWallet(address(splitMainV2));
  }

  function testCreateSplit() public {
    address[] memory accounts = new address[](2);
    accounts[0] = makeAddr("accounts0");
    accounts[1] = makeAddr("accounts1");

    uint32[] memory percentAllocations = new uint32[](2);
    percentAllocations[0] = 400_000;
    percentAllocations[1] = 600_000;

    // vm.expectNonRevert();
    splitMainV2.createSplit(address(splitWallet), accounts, percentAllocations, 0, address(0), address(this));
  }

  // function test
}
