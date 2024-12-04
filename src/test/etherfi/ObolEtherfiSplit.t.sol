// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ObolEtherfiSplitFactory, ObolEtherfiSplit, IweETH} from "src/etherfi/ObolEtherfiSplitFactory.sol";
import {BaseSplit} from "src/base/BaseSplit.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ObolEtherfiSplitTestHelper} from "./ObolEtherfiSplitTestHelper.sol";
import {MockERC20} from "src/test/utils/mocks/MockERC20.sol";

contract ObolEtherfiSplitTest is ObolEtherfiSplitTestHelper, Test {
  uint256 internal constant PERCENTAGE_SCALE = 1e5;

  ObolEtherfiSplitFactory internal etherfiSplitFactory;
  ObolEtherfiSplitFactory internal etherfiSplitFactoryWithFee;

  ObolEtherfiSplit internal etherfiSplit;
  ObolEtherfiSplit internal etherfiSplitWithFee;

  address demoSplit;
  address feeRecipient;
  uint256 feeShare;

  MockERC20 mERC20;

  function setUp() public {
    uint256 mainnetBlock = 19_393_100;
    vm.createSelectFork(getChain("mainnet").rpcUrl, mainnetBlock);

    feeRecipient = makeAddr("feeRecipient");
    feeShare = 1e4;

    etherfiSplitFactory =
      new ObolEtherfiSplitFactory(address(0), 0, ERC20(EETH_MAINNET_ADDRESS), ERC20(WEETH_MAINNET_ADDRESS));

    etherfiSplitFactoryWithFee =
      new ObolEtherfiSplitFactory(feeRecipient, feeShare, ERC20(EETH_MAINNET_ADDRESS), ERC20(WEETH_MAINNET_ADDRESS));

    demoSplit = makeAddr("demoSplit");

    etherfiSplit = ObolEtherfiSplit(etherfiSplitFactory.createCollector(address(0), demoSplit));
    etherfiSplitWithFee = ObolEtherfiSplit(etherfiSplitFactoryWithFee.createCollector(address(0), demoSplit));

    mERC20 = new MockERC20("Test Token", "TOK", 18);
    mERC20.mint(type(uint256).max);
  }

  function test_etherfi_CannotCreateInvalidFeeRecipient() public {
    vm.expectRevert(BaseSplit.Invalid_FeeRecipient.selector);
    new ObolEtherfiSplit(address(0), 10, ERC20(EETH_MAINNET_ADDRESS), ERC20(WEETH_MAINNET_ADDRESS));
  }

  function test_etherfi_CannotCreateInvalidFeeShare() public {
    vm.expectRevert(abi.encodeWithSelector(BaseSplit.Invalid_FeeShare.selector, PERCENTAGE_SCALE + 1));
    new ObolEtherfiSplit(address(1), PERCENTAGE_SCALE + 1, ERC20(EETH_MAINNET_ADDRESS), ERC20(WEETH_MAINNET_ADDRESS));

    vm.expectRevert(abi.encodeWithSelector(BaseSplit.Invalid_FeeShare.selector, PERCENTAGE_SCALE));
    new ObolEtherfiSplit(address(1), PERCENTAGE_SCALE, ERC20(EETH_MAINNET_ADDRESS), ERC20(WEETH_MAINNET_ADDRESS));
  }

  function test_etherfi_CloneArgsIsCorrect() public {
    assertEq(etherfiSplit.withdrawalAddress(), demoSplit, "invalid address");
    assertEq(address(etherfiSplit.eETH()), EETH_MAINNET_ADDRESS, "invalid eETH address");
    assertEq(address(etherfiSplit.weETH()), WEETH_MAINNET_ADDRESS, "invalid weETH address");
    assertEq(etherfiSplit.feeRecipient(), address(0), "invalid fee recipient");
    assertEq(etherfiSplit.feeShare(), 0, "invalid fee amount");

    assertEq(etherfiSplitWithFee.withdrawalAddress(), demoSplit, "invalid address");
    assertEq(address(etherfiSplitWithFee.eETH()), EETH_MAINNET_ADDRESS, "invalid eETH address");
    assertEq(address(etherfiSplitWithFee.weETH()), WEETH_MAINNET_ADDRESS, "invalid weETH address");
    assertEq(etherfiSplitWithFee.feeRecipient(), feeRecipient, "invalid fee recipient /2");
    assertEq(etherfiSplitWithFee.feeShare(), feeShare, "invalid fee share /2");
  }

  function test_etherfi_CanRescueFunds() public {
    // rescue ETH
    uint256 amountOfEther = 1 ether;
    deal(address(etherfiSplit), amountOfEther);

    uint256 balance = etherfiSplit.rescueFunds(address(0));
    assertEq(balance, amountOfEther, "balance not rescued");
    assertEq(address(etherfiSplit).balance, 0, "balance is not zero");
    assertEq(address(etherfiSplit.withdrawalAddress()).balance, amountOfEther, "rescue not successful");

    // rescue tokens
    mERC20.transfer(address(etherfiSplit), amountOfEther);
    uint256 tokenBalance = etherfiSplit.rescueFunds(address(mERC20));
    assertEq(tokenBalance, amountOfEther, "token - balance not rescued");
    assertEq(mERC20.balanceOf(address(etherfiSplit)), 0, "token - balance is not zero");
    assertEq(mERC20.balanceOf(etherfiSplit.withdrawalAddress()), amountOfEther, "token - rescue not successful");
  }

  function test_etherfi_Cannot_RescueEtherfiTokens() public {
    vm.expectRevert(BaseSplit.Invalid_Address.selector);
    etherfiSplit.rescueFunds(address(EETH_MAINNET_ADDRESS));

    vm.expectRevert(BaseSplit.Invalid_Address.selector);
    etherfiSplit.rescueFunds(address(WEETH_MAINNET_ADDRESS));
  }

  function test_etherfi_CanDistributeWithoutFee() public {
    // we use a random account on Etherscan to credit the etherfiSplit address
    // with 10 ether worth of eETH on mainnet
    vm.prank(RANDOM_EETH_ACCOUNT_ADDRESS);
    ERC20(EETH_MAINNET_ADDRESS).transfer(address(etherfiSplit), 100 ether);

    uint256 prevBalance = ERC20(WEETH_MAINNET_ADDRESS).balanceOf(demoSplit);

    uint256 amount = etherfiSplit.distribute();

    assertTrue(amount > 0, "invalid amount");

    uint256 afterBalance = ERC20(WEETH_MAINNET_ADDRESS).balanceOf(demoSplit);

    assertGe(afterBalance, prevBalance, "after balance greater");
  }

  function test_etherfi_CanDistributeWithFee() public {
    // we use a random account on Etherscan to credit the etherfiSplit address
    // with 10 ether worth of eETH on mainnet
    vm.prank(RANDOM_EETH_ACCOUNT_ADDRESS);
    uint256 amountToDistribute = 100 ether;
    ERC20(EETH_MAINNET_ADDRESS).transfer(address(etherfiSplitWithFee), amountToDistribute);

    uint256 prevBalance = ERC20(WEETH_MAINNET_ADDRESS).balanceOf(demoSplit);

    uint256 balance = ERC20(EETH_MAINNET_ADDRESS).balanceOf(address(etherfiSplitWithFee));

    uint256 weETHDistributed = IweETH(WEETH_MAINNET_ADDRESS).getWeETHByeETH(balance);

    uint256 amount = etherfiSplitWithFee.distribute();

    assertTrue(amount > 0, "invalid amount");

    uint256 afterBalance = ERC20(WEETH_MAINNET_ADDRESS).balanceOf(demoSplit);

    assertGe(afterBalance, prevBalance, "after balance greater");

    uint256 expectedFee = (weETHDistributed * feeShare) / PERCENTAGE_SCALE;

    assertEq(ERC20(WEETH_MAINNET_ADDRESS).balanceOf(feeRecipient), expectedFee, "invalid fee transferred");

    assertEq(ERC20(WEETH_MAINNET_ADDRESS).balanceOf(demoSplit), weETHDistributed - expectedFee, "invalid amount");
  }

  function testFuzz_etherfi_CanDistributeWithFee(
    address anotherSplit,
    uint256 amountToDistribute,
    address fuzzFeeRecipient,
    uint256 fuzzFeeShare
  ) public {
    vm.assume(anotherSplit != address(0));
    vm.assume(fuzzFeeRecipient != anotherSplit);
    vm.assume(fuzzFeeShare > 0 && fuzzFeeShare < PERCENTAGE_SCALE);
    vm.assume(fuzzFeeRecipient != address(0));
    vm.assume(amountToDistribute > 1 ether);
    vm.assume(amountToDistribute < 10 ether);

    ObolEtherfiSplitFactory fuzzFactorySplitWithFee = new ObolEtherfiSplitFactory(
      fuzzFeeRecipient, fuzzFeeShare, ERC20(EETH_MAINNET_ADDRESS), ERC20(WEETH_MAINNET_ADDRESS)
    );

    ObolEtherfiSplit fuzzSplitWithFee =
      ObolEtherfiSplit(fuzzFactorySplitWithFee.createCollector(address(0), anotherSplit));

    vm.prank(RANDOM_EETH_ACCOUNT_ADDRESS);

    ERC20(EETH_MAINNET_ADDRESS).transfer(address(fuzzSplitWithFee), amountToDistribute);

    uint256 prevBalance = ERC20(WEETH_MAINNET_ADDRESS).balanceOf(anotherSplit);

    uint256 balance = ERC20(EETH_MAINNET_ADDRESS).balanceOf(address(fuzzSplitWithFee));

    uint256 weETHDistributed = IweETH(WEETH_MAINNET_ADDRESS).getWeETHByeETH(balance);

    uint256 amount = fuzzSplitWithFee.distribute();

    assertTrue(amount > 0, "invalid amount");

    uint256 afterBalance = ERC20(WEETH_MAINNET_ADDRESS).balanceOf(anotherSplit);

    assertGe(afterBalance, prevBalance, "after balance greater");

    uint256 expectedFee = (weETHDistributed * fuzzFeeShare) / PERCENTAGE_SCALE;

    assertEq(ERC20(WEETH_MAINNET_ADDRESS).balanceOf(fuzzFeeRecipient), expectedFee, "invalid fee transferred");

    assertEq(ERC20(WEETH_MAINNET_ADDRESS).balanceOf(anotherSplit), weETHDistributed - expectedFee, "invalid amount");
  }
}
