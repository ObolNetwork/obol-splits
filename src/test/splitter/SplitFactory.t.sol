// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import {SplitFactory} from "src/splitter/SplitFactory.sol";
import {SplitMainV2} from "src/splitter/SplitMainV2.sol";
import {SplitWallet} from "src/splitter/SplitWallet.sol";

contract SplitFactoryTest is Test {
  SplitFactory public splitFactory;
  SplitMainV2 public splitMainV2;
  SplitWallet public splitWallet;

  bytes32 internal splitWalletId = keccak256("splitWallet");

  function setUp() public {
    splitFactory = new SplitFactory(address(this));
    // fetch splitMain from splitFactory
    splitMainV2 = SplitMainV2(payable(address(splitFactory.splitMain())));
    splitWallet = new SplitWallet(address(splitMainV2));
  }

  function testAddSplitWallet() public {
    splitFactory.addSplitWallet(splitWalletId, address(splitWallet));
  }

  function testCreateSplit() public {
    // add split wallet
    splitFactory.addSplitWallet(splitWalletId, address(splitWallet));

    address[] memory accounts = new address[](2);
    accounts[0] = makeAddr("accounts0");
    accounts[1] = makeAddr("accounts1");

    uint32[] memory percentAllocations = new uint32[](2);
    percentAllocations[0] = 400_000;
    percentAllocations[1] = 600_000;

    splitFactory.createSplit(splitWalletId, accounts, percentAllocations, 0, address(this), address(0));
  }
}
