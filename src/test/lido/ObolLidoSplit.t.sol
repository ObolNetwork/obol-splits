// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ObolLidoSplitFactory, ObolLidoSplit, IwstETH} from "src/lido/ObolLidoSplitFactory.sol";
import {BaseSplit} from "src/base/BaseSplit.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ObolLidoSplitTestHelper} from "./ObolLidoSplitTestHelper.sol";
import {MockERC20} from "src/test/utils/mocks/MockERC20.sol";

contract ObolLidoSplitTest is ObolLidoSplitTestHelper, Test {
  uint256 internal constant PERCENTAGE_SCALE = 1e5;

  ObolLidoSplitFactory internal lidoSplitFactory;
  ObolLidoSplitFactory internal lidoSplitFactoryWithFee;

  ObolLidoSplit internal lidoSplit;
  ObolLidoSplit internal lidoSplitWithFee;

  address demoSplit;
  address feeRecipient;
  uint256 feeShare;

  MockERC20 mERC20;

  function setUp() public {
    uint256 mainnetBlock = 17_421_005;
    vm.createSelectFork(getChain("mainnet").rpcUrl, mainnetBlock);

    feeRecipient = makeAddr("feeRecipient");
    feeShare = 1e4;

    lidoSplitFactory =
      new ObolLidoSplitFactory(address(0), 0, ERC20(STETH_MAINNET_ADDRESS), ERC20(WSTETH_MAINNET_ADDRESS));

    lidoSplitFactoryWithFee =
      new ObolLidoSplitFactory(feeRecipient, feeShare, ERC20(STETH_MAINNET_ADDRESS), ERC20(WSTETH_MAINNET_ADDRESS));

    demoSplit = makeAddr("demoSplit");

    lidoSplit = ObolLidoSplit(lidoSplitFactory.createCollector(address(0), demoSplit));
    lidoSplitWithFee = ObolLidoSplit(lidoSplitFactoryWithFee.createCollector(address(0), demoSplit));

    mERC20 = new MockERC20("Test Token", "TOK", 18);
    mERC20.mint(type(uint256).max);
  }

  function test_CannotCreateInvalidFeeRecipient() public {
    vm.expectRevert(BaseSplit.Invalid_FeeRecipient.selector);
    new ObolLidoSplit(address(0), 10, ERC20(STETH_MAINNET_ADDRESS), ERC20(WSTETH_MAINNET_ADDRESS));
  }

  function test_CannotCreateInvalidFeeShare() public {
    vm.expectRevert(abi.encodeWithSelector(BaseSplit.Invalid_FeeShare.selector, PERCENTAGE_SCALE + 1));
    new ObolLidoSplit(address(1), PERCENTAGE_SCALE + 1, ERC20(STETH_MAINNET_ADDRESS), ERC20(WSTETH_MAINNET_ADDRESS));

    vm.expectRevert(abi.encodeWithSelector(BaseSplit.Invalid_FeeShare.selector, PERCENTAGE_SCALE));
    new ObolLidoSplit(address(1), PERCENTAGE_SCALE, ERC20(STETH_MAINNET_ADDRESS), ERC20(WSTETH_MAINNET_ADDRESS));
  }

  function test_CloneArgsIsCorrect() public {
    assertEq(lidoSplit.withdrawalAddress(), demoSplit, "invalid address");
    assertEq(address(lidoSplit.stETH()), STETH_MAINNET_ADDRESS, "invalid stETH address");
    assertEq(address(lidoSplit.wstETH()), WSTETH_MAINNET_ADDRESS, "invalid wstETH address");
    assertEq(lidoSplit.feeRecipient(), address(0), "invalid fee recipient");
    assertEq(lidoSplit.feeShare(), 0, "invalid fee amount");

    assertEq(lidoSplitWithFee.withdrawalAddress(), demoSplit, "invalid address");
    assertEq(address(lidoSplitWithFee.stETH()), STETH_MAINNET_ADDRESS, "invalid stETH address");
    assertEq(address(lidoSplitWithFee.wstETH()), WSTETH_MAINNET_ADDRESS, "invalid wstETH address");
    assertEq(lidoSplitWithFee.feeRecipient(), feeRecipient, "invalid fee recipient /2");
    assertEq(lidoSplitWithFee.feeShare(), feeShare, "invalid fee share /2");
  }

  function test_CanRescueFunds() public {
    // rescue ETH
    uint256 amountOfEther = 1 ether;
    deal(address(lidoSplit), amountOfEther);

    uint256 balance = lidoSplit.rescueFunds(address(0));
    assertEq(balance, amountOfEther, "balance not rescued");
    assertEq(address(lidoSplit).balance, 0, "balance is not zero");
    assertEq(address(lidoSplit.withdrawalAddress()).balance, amountOfEther, "rescue not successful");

    // rescue tokens
    mERC20.transfer(address(lidoSplit), amountOfEther);
    uint256 tokenBalance = lidoSplit.rescueFunds(address(mERC20));
    assertEq(tokenBalance, amountOfEther, "token - balance not rescued");
    assertEq(mERC20.balanceOf(address(lidoSplit)), 0, "token - balance is not zero");
    assertEq(mERC20.balanceOf(lidoSplit.withdrawalAddress()), amountOfEther, "token - rescue not successful");
  }

  function testCannot_RescueLidoTokens() public {
    vm.expectRevert(BaseSplit.Invalid_Address.selector);
    lidoSplit.rescueFunds(address(STETH_MAINNET_ADDRESS));

    vm.expectRevert(BaseSplit.Invalid_Address.selector);
    lidoSplit.rescueFunds(address(WSTETH_MAINNET_ADDRESS));
  }

  function test_CanDistributeWithoutFee() public {
    // we use a random account on Etherscan to credit the lidoSplit address
    // with 10 ether worth of stETH on mainnet
    vm.prank(0x2bf3937b8BcccE4B65650F122Bb3f1976B937B2f);
    ERC20(STETH_MAINNET_ADDRESS).transfer(address(lidoSplit), 100 ether);

    uint256 prevBalance = ERC20(WSTETH_MAINNET_ADDRESS).balanceOf(demoSplit);

    uint256 amount = lidoSplit.distribute();

    assertTrue(amount > 0, "invalid amount");

    uint256 afterBalance = ERC20(WSTETH_MAINNET_ADDRESS).balanceOf(demoSplit);

    assertGe(afterBalance, prevBalance, "after balance greater");
  }

  function test_CanDistributeWithFee() public {
    // we use a random account on Etherscan to credit the lidoSplit address
    // with 10 ether worth of stETH on mainnet
    vm.prank(0x2bf3937b8BcccE4B65650F122Bb3f1976B937B2f);
    uint256 amountToDistribute = 100 ether;
    ERC20(STETH_MAINNET_ADDRESS).transfer(address(lidoSplitWithFee), amountToDistribute);

    uint256 prevBalance = ERC20(WSTETH_MAINNET_ADDRESS).balanceOf(demoSplit);

    uint256 balance = ERC20(STETH_MAINNET_ADDRESS).balanceOf(address(lidoSplitWithFee));

    uint256 wstETHDistributed = IwstETH(WSTETH_MAINNET_ADDRESS).getWstETHByStETH(balance);

    uint256 amount = lidoSplitWithFee.distribute();

    assertTrue(amount > 0, "invalid amount");

    uint256 afterBalance = ERC20(WSTETH_MAINNET_ADDRESS).balanceOf(demoSplit);

    assertGe(afterBalance, prevBalance, "after balance greater");

    uint256 expectedFee = (wstETHDistributed * feeShare) / PERCENTAGE_SCALE;

    assertEq(ERC20(WSTETH_MAINNET_ADDRESS).balanceOf(feeRecipient), expectedFee, "invalid fee transferred");

    assertEq(ERC20(WSTETH_MAINNET_ADDRESS).balanceOf(demoSplit), wstETHDistributed - expectedFee, "invalid amount");
  }

  function testFuzz_CanDistributeWithFee(
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

    ObolLidoSplitFactory fuzzFactorySplitWithFee = new ObolLidoSplitFactory(
      fuzzFeeRecipient, fuzzFeeShare, ERC20(STETH_MAINNET_ADDRESS), ERC20(WSTETH_MAINNET_ADDRESS)
    );

    ObolLidoSplit fuzzSplitWithFee = ObolLidoSplit(fuzzFactorySplitWithFee.createCollector(address(0), anotherSplit));

    vm.prank(0x2bf3937b8BcccE4B65650F122Bb3f1976B937B2f);

    ERC20(STETH_MAINNET_ADDRESS).transfer(address(fuzzSplitWithFee), amountToDistribute);

    uint256 prevBalance = ERC20(WSTETH_MAINNET_ADDRESS).balanceOf(anotherSplit);

    uint256 balance = ERC20(STETH_MAINNET_ADDRESS).balanceOf(address(fuzzSplitWithFee));

    uint256 wstETHDistributed = IwstETH(WSTETH_MAINNET_ADDRESS).getWstETHByStETH(balance);

    uint256 amount = fuzzSplitWithFee.distribute();

    assertTrue(amount > 0, "invalid amount");

    uint256 afterBalance = ERC20(WSTETH_MAINNET_ADDRESS).balanceOf(anotherSplit);

    assertGe(afterBalance, prevBalance, "after balance greater");

    uint256 expectedFee = (wstETHDistributed * fuzzFeeShare) / PERCENTAGE_SCALE;

    assertEq(ERC20(WSTETH_MAINNET_ADDRESS).balanceOf(fuzzFeeRecipient), expectedFee, "invalid fee transferred");

    assertEq(ERC20(WSTETH_MAINNET_ADDRESS).balanceOf(anotherSplit), wstETHDistributed - expectedFee, "invalid amount");
  }
}
