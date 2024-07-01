// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ObolCollectorFactory, ObolCollector} from "src/collector/ObolCollectorFactory.sol";
import {MockERC20} from "src/test/utils/mocks/MockERC20.sol";
import {BaseSplit} from "src/base/BaseSplit.sol";

contract ObolCollectorTest is Test {

  uint256 internal constant PERCENTAGE_SCALE = 1e5;

  address feeRecipient;
  address withdrawalAddress;
  address ethWithdrawalAddress;

  uint256 feeShare;
  MockERC20 mERC20;
  MockERC20 rescueERC20;

  ObolCollectorFactory collectorFactoryWithFee;

  ObolCollector collectorWithFee;
  ObolCollector ethCollectorWithFee;

  function setUp() public {
    feeRecipient = makeAddr("feeRecipient");
    withdrawalAddress = makeAddr("withdrawalAddress");
    ethWithdrawalAddress = makeAddr("ethWithdrawalAddress");
    mERC20 = new MockERC20("Test Token", "TOK", 18);
    rescueERC20 = new MockERC20("Rescue Test Token", "TOK", 18);

    feeShare = 1e4; // 10%
    collectorFactoryWithFee = new ObolCollectorFactory(feeRecipient, feeShare);

    collectorWithFee = ObolCollector(collectorFactoryWithFee.createCollector(address(mERC20), withdrawalAddress));
    ethCollectorWithFee = ObolCollector(collectorFactoryWithFee.createCollector(address(0), ethWithdrawalAddress));

    mERC20.mint(type(uint256).max);
    rescueERC20.mint(type(uint256).max);
  }

  function test_InvalidFeeShare() public {
    vm.expectRevert(abi.encodeWithSelector(BaseSplit.Invalid_FeeShare.selector, 1e10));
    new ObolCollectorFactory(address(0), 1e10);

    vm.expectRevert(abi.encodeWithSelector(BaseSplit.Invalid_FeeShare.selector, 1e5));
    new ObolCollectorFactory(address(0), 1e5);
  }

  function test_feeShare() public {
    assertEq(collectorWithFee.feeShare(), feeShare, "invalid collector fee");

    assertEq(ethCollectorWithFee.feeShare(), feeShare, "invalid collector value fee");
  }

  function test_feeRecipient() public {
    assertEq(collectorWithFee.feeRecipient(), feeRecipient, "invalid collector feeRecipient");

    assertEq(ethCollectorWithFee.feeRecipient(), feeRecipient, "invalid collector feeRecipient 2");
  }

  function test_withdrawalAddress() public {
    assertEq(collectorWithFee.withdrawalAddress(), withdrawalAddress, "invalid split wallet");

    assertEq(ethCollectorWithFee.withdrawalAddress(), ethWithdrawalAddress, "invalid eth split wallet");
  }

  function test_token() public {
    assertEq(collectorWithFee.token(), address(mERC20), "invalid token");

    assertEq(ethCollectorWithFee.token(), address(0), "ivnalid token eth");
  }

  function test_DistributeERC20WithFee() public {
    uint256 amountToDistribute = 10 ether;

    mERC20.transfer(address(collectorWithFee), amountToDistribute);

    collectorWithFee.distribute();

    uint256 fee = amountToDistribute * feeShare / PERCENTAGE_SCALE;

    assertEq(mERC20.balanceOf(feeRecipient), fee, "invalid fee share");

    assertEq(mERC20.balanceOf(withdrawalAddress), amountToDistribute - fee, "invalid amount to split");
  }

  function testFuzz_DistributeERC20WithFee(
    uint256 amountToDistribute,
    uint256 fuzzFeeShare,
    address fuzzFeeRecipient,
    address fuzzWithdrawalAddress
  ) public {
    vm.assume(amountToDistribute > 0);
    vm.assume(fuzzWithdrawalAddress != address(0));
    vm.assume(fuzzFeeRecipient != address(0));

    amountToDistribute = bound(amountToDistribute, 1, type(uint128).max);
    fuzzFeeShare = bound(fuzzFeeShare, 1, 8 * 1e4);

    ObolCollectorFactory fuzzCollectorFactoryWithFee = new ObolCollectorFactory(fuzzFeeRecipient, fuzzFeeShare);
    ObolCollector fuzzCollectorWithFee =
      ObolCollector(fuzzCollectorFactoryWithFee.createCollector(address(mERC20), fuzzWithdrawalAddress));

    uint256 feeRecipientBalancePrev = mERC20.balanceOf(fuzzFeeRecipient);
    uint256 fuzzWithdrawalAddressBalancePrev = mERC20.balanceOf(fuzzWithdrawalAddress);

    mERC20.transfer(address(fuzzCollectorWithFee), amountToDistribute);

    fuzzCollectorWithFee.distribute();

    uint256 fee = amountToDistribute * fuzzFeeShare / PERCENTAGE_SCALE;

    assertEq(mERC20.balanceOf(fuzzFeeRecipient), feeRecipientBalancePrev + fee, "invalid fee share");

    assertEq(
      mERC20.balanceOf(fuzzWithdrawalAddress),
      fuzzWithdrawalAddressBalancePrev + amountToDistribute - fee,
      "invalid amount to split"
    );
  }

  function test_DistributeETHWithFee() public {
    uint256 amountToDistribute = 10 ether;

    vm.deal(address(ethCollectorWithFee), amountToDistribute);

    ethCollectorWithFee.distribute();

    uint256 fee = amountToDistribute * feeShare / PERCENTAGE_SCALE;

    assertEq(address(feeRecipient).balance, fee, "invalid fee share");

    assertEq(address(ethWithdrawalAddress).balance, amountToDistribute - fee, "invalid amount to split");
  }

  function testFuzz_DistributeETHWithFee(uint256 amountToDistribute, uint256 fuzzFeeShare) public {
    vm.assume(amountToDistribute > 0);
    vm.assume(fuzzFeeShare > 0);

    address fuzzWithdrawalAddress = makeAddr("fuzzWithdrawalAddress");
    address fuzzFeeRecipient = makeAddr("fuzzFeeRecipient");

    amountToDistribute = bound(amountToDistribute, 1, type(uint96).max);
    fuzzFeeShare = bound(fuzzFeeShare, 1, 9 * 1e4);

    ObolCollectorFactory fuzzCollectorFactoryWithFee = new ObolCollectorFactory(fuzzFeeRecipient, fuzzFeeShare);
    ObolCollector fuzzETHCollectorWithFee =
      ObolCollector(fuzzCollectorFactoryWithFee.createCollector(address(0), fuzzWithdrawalAddress));

    vm.deal(address(fuzzETHCollectorWithFee), amountToDistribute);

    uint256 fuzzFeeRecipientBalance = address(fuzzFeeRecipient).balance;
    uint256 fuzzWithdrawalAddressBalance = address(fuzzWithdrawalAddress).balance;

    fuzzETHCollectorWithFee.distribute();

    uint256 fee = amountToDistribute * fuzzFeeShare / PERCENTAGE_SCALE;

    assertEq(address(fuzzFeeRecipient).balance, fuzzFeeRecipientBalance + fee, "invalid fee share");

    assertEq(
      address(fuzzWithdrawalAddress).balance,
      fuzzWithdrawalAddressBalance + amountToDistribute - fee,
      "invalid amount to split"
    );
  }

  function testCannot_RescueControllerToken() public {
    deal(address(ethCollectorWithFee), 1 ether);
    vm.expectRevert(BaseSplit.Invalid_Address.selector);
    ethCollectorWithFee.rescueFunds(address(0));

    mERC20.transfer(address(collectorWithFee), 1 ether);
    vm.expectRevert(BaseSplit.Invalid_Address.selector);
    collectorWithFee.rescueFunds(address(mERC20));
  }

  function test_RescueTokens() public {
    uint256 amountToRescue = 1 ether;
    deal(address(collectorWithFee), amountToRescue);
    collectorWithFee.rescueFunds(address(0));

    assertEq(address(withdrawalAddress).balance, amountToRescue, "invalid amount");

    rescueERC20.transfer(address(collectorWithFee), amountToRescue);
    collectorWithFee.rescueFunds(address(rescueERC20));
    assertEq(rescueERC20.balanceOf(withdrawalAddress), amountToRescue, "invalid erc20 amount");

    // ETH
    rescueERC20.transfer(address(ethCollectorWithFee), amountToRescue);
    ethCollectorWithFee.rescueFunds(address(rescueERC20));

    assertEq(rescueERC20.balanceOf(ethWithdrawalAddress), amountToRescue, "invalid erc20 amount");
  }
}
