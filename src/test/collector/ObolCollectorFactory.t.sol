// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ObolCollectorFactory, ObolCollector} from "src/collector/ObolCollectorFactory.sol";
import {MockERC20} from "src/test/utils/mocks/MockERC20.sol";

contract ObolCollectorFactoryTest is Test {
  error Invalid_Address();

  address feeRecipient;
  uint256 feeShare;
  address splitWallet;

  ObolCollectorFactory collectorFactory;

  function setUp() public {
    feeRecipient = makeAddr("feeRecipient");
    splitWallet = makeAddr("splitWallet");
    feeShare = 1e4; // 10%
    collectorFactory = new ObolCollectorFactory(feeRecipient, feeShare);
  }

  function testCannot_CreateCollectorInvalidWithdrawalAddress() public {
    vm.expectRevert(Invalid_Address.selector);
    collectorFactory.createCollector(address(0), address(0));
  }

  function test_CreateCollector() public {
    collectorFactory.createCollector(address(0), splitWallet);
  }
}
