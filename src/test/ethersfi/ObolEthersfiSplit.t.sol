// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ObolEthersfiSplitFactory, ObolEthersfiSplit, IweETH} from "src/ethersfi/ObolEthersfiSplitFactory.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ObolEthersfiSplitTestHelper} from "./ObolEthersfiSplitTestHelper.sol";
import {MockERC20} from "src/test/utils/mocks/MockERC20.sol";

contract ObolEthersfiSplitTest is ObolEthersfiSplitTestHelper, Test {
  uint256 internal constant PERCENTAGE_SCALE = 1e5;

  ObolEthersfiSplitFactory internal ethersfiSplitFactory;
  ObolEthersfiSplitFactory internal ethersfiSplitFactoryWithFee;

  ObolEthersfiSplit internal ethersfiSplit;
  ObolEthersfiSplit internal ethersfiSplitWithFee;

  address demoSplit;
  address feeRecipient;
  uint256 feeShare;

  MockERC20 mERC20;

  function setUp() public {
    uint256 mainnetBlock = 19_228_949;
    vm.createSelectFork(getChain("mainnet").rpcUrl, mainnetBlock);

    feeRecipient = makeAddr("feeRecipient");
    feeShare = 1e4;

    ethersfiSplitFactory =
      new ObolEthersfiSplitFactory(address(0), 0, ERC20(EETH_MAINNET_ADDRESS), ERC20(WEETH_MAINNET_ADDRESS));

    ethersfiSplitFactoryWithFee =
      new ObolEthersfiSplitFactory(feeRecipient, feeShare, ERC20(EETH_MAINNET_ADDRESS), ERC20(WEETH_MAINNET_ADDRESS));

    demoSplit = makeAddr("demoSplit");

    ethersfiSplit = ObolEthersfiSplit(ethersfiSplitFactory.createSplit(demoSplit));
    ethersfiSplitWithFee = ObolEthersfiSplit(ethersfiSplitFactoryWithFee.createSplit(demoSplit));

    mERC20 = new MockERC20("Test Token", "TOK", 18);
    mERC20.mint(type(uint256).max);
  }

  function test_ethersfi_CannotCreateInvalidFeeRecipient() public {
    vm.expectRevert(ObolEthersfiSplit.Invalid_FeeRecipient.selector);
    new ObolEthersfiSplit(address(0), 10, ERC20(EETH_MAINNET_ADDRESS), ERC20(WEETH_MAINNET_ADDRESS));
  }

  function test_ethersfi_CannotCreateInvalidFeeShare() public {
    vm.expectRevert(abi.encodeWithSelector(ObolEthersfiSplit.Invalid_FeeShare.selector, PERCENTAGE_SCALE + 1));
    new ObolEthersfiSplit(address(1), PERCENTAGE_SCALE + 1, ERC20(EETH_MAINNET_ADDRESS), ERC20(WEETH_MAINNET_ADDRESS));

    vm.expectRevert(abi.encodeWithSelector(ObolEthersfiSplit.Invalid_FeeShare.selector, PERCENTAGE_SCALE));
    new ObolEthersfiSplit(address(1), PERCENTAGE_SCALE, ERC20(EETH_MAINNET_ADDRESS), ERC20(WEETH_MAINNET_ADDRESS));
  }

  function test_ethersfi_CloneArgsIsCorrect() public {
    assertEq(ethersfiSplit.splitWallet(), demoSplit, "invalid address");
    assertEq(address(ethersfiSplit.eETH()), EETH_MAINNET_ADDRESS, "invalid eETH address");
    assertEq(address(ethersfiSplit.weETH()), WEETH_MAINNET_ADDRESS, "invalid weETH address");
    assertEq(ethersfiSplit.feeRecipient(), address(0), "invalid fee recipient");
    assertEq(ethersfiSplit.feeShare(), 0, "invalid fee amount");

    assertEq(ethersfiSplitWithFee.splitWallet(), demoSplit, "invalid address");
    assertEq(address(ethersfiSplitWithFee.eETH()), EETH_MAINNET_ADDRESS, "invalid eETH address");
    assertEq(address(ethersfiSplitWithFee.weETH()), WEETH_MAINNET_ADDRESS, "invalid weETH address");
    assertEq(ethersfiSplitWithFee.feeRecipient(), feeRecipient, "invalid fee recipient /2");
    assertEq(ethersfiSplitWithFee.feeShare(), feeShare, "invalid fee share /2");
  }

  function test_ethersfi_CanRescueFunds() public {
    // rescue ETH
    uint256 amountOfEther = 1 ether;
    deal(address(ethersfiSplit), amountOfEther);

    uint256 balance = ethersfiSplit.rescueFunds(address(0));
    assertEq(balance, amountOfEther, "balance not rescued");
    assertEq(address(ethersfiSplit).balance, 0, "balance is not zero");
    assertEq(address(ethersfiSplit.splitWallet()).balance, amountOfEther, "rescue not successful");

    // rescue tokens
    mERC20.transfer(address(ethersfiSplit), amountOfEther);
    uint256 tokenBalance = ethersfiSplit.rescueFunds(address(mERC20));
    assertEq(tokenBalance, amountOfEther, "token - balance not rescued");
    assertEq(mERC20.balanceOf(address(ethersfiSplit)), 0, "token - balance is not zero");
    assertEq(mERC20.balanceOf(ethersfiSplit.splitWallet()), amountOfEther, "token - rescue not successful");
  }

  function test_ethersfi_Cannot_RescueEthersfiTokens() public {
    vm.expectRevert(ObolEthersfiSplit.Invalid_Address.selector);
    ethersfiSplit.rescueFunds(address(EETH_MAINNET_ADDRESS));

    vm.expectRevert(ObolEthersfiSplit.Invalid_Address.selector);
    ethersfiSplit.rescueFunds(address(WEETH_MAINNET_ADDRESS));
  }

  function test_ethersfi_CanDistributeWithoutFee() public {
    // we use a random account on Etherscan to credit the ethersfiSplit address
    // with 10 ether worth of eETH on mainnet
    vm.prank(RANDOM_EETH_ACCOUNT_ADDRESS);
    ERC20(EETH_MAINNET_ADDRESS).transfer(address(ethersfiSplit), 100 ether);

    uint256 prevBalance = ERC20(WEETH_MAINNET_ADDRESS).balanceOf(demoSplit);

    uint256 amount = ethersfiSplit.distribute();

    assertTrue(amount > 0, "invalid amount");

    uint256 afterBalance = ERC20(WEETH_MAINNET_ADDRESS).balanceOf(demoSplit);

    assertGe(afterBalance, prevBalance, "after balance greater");
  }

  function test_ethersfi_CanDistributeWithFee() public {
    // we use a random account on Etherscan to credit the ethersfiSplit address
    // with 10 ether worth of eETH on mainnet
    vm.prank(RANDOM_EETH_ACCOUNT_ADDRESS);
    uint256 amountToDistribute = 100 ether;
    ERC20(EETH_MAINNET_ADDRESS).transfer(address(ethersfiSplitWithFee), amountToDistribute);

    uint256 prevBalance = ERC20(WEETH_MAINNET_ADDRESS).balanceOf(demoSplit);

    uint256 balance = ERC20(EETH_MAINNET_ADDRESS).balanceOf(address(ethersfiSplitWithFee));

    uint256 weETHDistributed = IweETH(WEETH_MAINNET_ADDRESS).getWeETHByeETH(balance);

    uint256 amount = ethersfiSplitWithFee.distribute();

    assertTrue(amount > 0, "invalid amount");

    uint256 afterBalance = ERC20(WEETH_MAINNET_ADDRESS).balanceOf(demoSplit);

    assertGe(afterBalance, prevBalance, "after balance greater");

    uint256 expectedFee = (weETHDistributed * feeShare) / PERCENTAGE_SCALE;

    assertEq(ERC20(WEETH_MAINNET_ADDRESS).balanceOf(feeRecipient), expectedFee, "invalid fee transferred");

    assertEq(ERC20(WEETH_MAINNET_ADDRESS).balanceOf(demoSplit), weETHDistributed - expectedFee, "invalid amount");
  }

  function testFuzz_ethersfi_CanDistributeWithFee(
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

    ObolEthersfiSplitFactory fuzzFactorySplitWithFee = new ObolEthersfiSplitFactory(
      fuzzFeeRecipient, fuzzFeeShare, ERC20(EETH_MAINNET_ADDRESS), ERC20(WEETH_MAINNET_ADDRESS)
    );

    ObolEthersfiSplit fuzzSplitWithFee = ObolEthersfiSplit(fuzzFactorySplitWithFee.createSplit(anotherSplit));

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
