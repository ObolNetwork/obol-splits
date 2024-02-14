// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {MockERC20} from "src/test/utils/mocks/MockERC20.sol";
import {ObolStakewiseSplitFactory, ObolStakewiseSplit} from "src/stakewise/ObolStakewiseSplitFactory.sol";

contract ObolStakewiseSplitTest is Test {
  uint256 internal constant PERCENTAGE_SCALE = 1e5;

  ObolStakewiseSplitFactory internal stakewiseSplitFactory;
  ObolStakewiseSplitFactory internal stakewiseSplitFactoryWithFee;

  ObolStakewiseSplit internal stakewiseSplit;
  ObolStakewiseSplit internal stakewiseSplitWithFee;

  address demoSplit;

  address feeRecipient;
  uint256 feeShare;

  MockERC20 vaultToken;
  MockERC20 canRescueToken;
  uint256 tokenAmount;

  function setUp() public {
    uint256 mainnetBlock = 19_167_592;
    vm.createSelectFork(getChain("mainnet").rpcUrl, mainnetBlock);

    feeShare = 1e4; //10%
    demoSplit = makeAddr("StakewiseDemoSplit");
    feeRecipient = makeAddr("StakewiseFeeRecipient");
    vaultToken = new MockERC20("Test", "TST", uint8(18));
    canRescueToken = new MockERC20("Test2", "TST2", uint8(18));

    stakewiseSplitFactory = new ObolStakewiseSplitFactory(address(0), 0);
    stakewiseSplitFactoryWithFee = new ObolStakewiseSplitFactory(feeRecipient, feeShare);

    stakewiseSplit = ObolStakewiseSplit(stakewiseSplitFactory.createSplit(demoSplit, address(vaultToken)));
    stakewiseSplitWithFee = ObolStakewiseSplit(stakewiseSplitFactoryWithFee.createSplit(demoSplit, address(vaultToken)));

    tokenAmount = 1000 * 1e18;
  }

  function test_stakewise_CannotCreateInvalidFeeRecipient() public {
    vm.expectRevert(ObolStakewiseSplit.Invalid_FeeRecipient.selector);
    new ObolStakewiseSplit(address(0), 1);
  }

  function test_stakewise_cannotCreateInvalidFeeShare() public {
    vm.expectRevert(abi.encodeWithSelector(ObolStakewiseSplit.Invalid_FeeShare.selector, PERCENTAGE_SCALE + 1));
    new ObolStakewiseSplit(address(1), PERCENTAGE_SCALE + 1);

    vm.expectRevert(abi.encodeWithSelector(ObolStakewiseSplit.Invalid_FeeShare.selector, PERCENTAGE_SCALE));
    new ObolStakewiseSplit(address(1), PERCENTAGE_SCALE);
  }

  function test_stakewise_cloneArgsAreCorrect() public {
    assertEq(stakewiseSplit.splitWallet(), demoSplit, "invalid address");
    assertEq(address(stakewiseSplit.vaultToken()), address(vaultToken), "invalid vault token address");
    assertEq(stakewiseSplit.feeRecipient(), address(0), "invalid fee recipient");
    assertEq(stakewiseSplit.feeShare(), 0, "invalid fee amount");

    assertEq(stakewiseSplitWithFee.splitWallet(), demoSplit, "invalid address");
    assertEq(address(stakewiseSplitWithFee.vaultToken()), address(vaultToken), "invalid vault token address");
    assertEq(stakewiseSplitWithFee.feeRecipient(), feeRecipient, "invalid fee recipient /2");
    assertEq(stakewiseSplitWithFee.feeShare(), feeShare, "invalid fee share /2");
  }

  function test_stakewise_canRescueFunds() public {
    // rescue ETH
    uint256 amountOfEther = 1 ether;
    deal(address(stakewiseSplit), amountOfEther);

    uint256 balance = stakewiseSplit.rescueFunds(address(0));
    assertEq(balance, amountOfEther, "balance not rescued");
    assertEq(address(stakewiseSplit).balance, 0, "balance is not zero");
    assertEq(address(stakewiseSplit.splitWallet()).balance, amountOfEther, "rescue not successful");

    // rescue tokens
    deal(address(canRescueToken), address(stakewiseSplit), tokenAmount);
    uint256 tokenBalance = stakewiseSplit.rescueFunds(address(canRescueToken));
    assertEq(tokenBalance, tokenAmount, "token - balance not rescued");
    assertEq(canRescueToken.balanceOf(address(stakewiseSplit)), 0, "token - balance is not zero");
    assertEq(canRescueToken.balanceOf(stakewiseSplit.splitWallet()), tokenAmount, "token - rescue not successful");
  }

  function test_stakewise_cannotVaultTokens() public {
    deal(address(vaultToken), address(stakewiseSplit), tokenAmount);
    vm.expectRevert(ObolStakewiseSplit.Invalid_Address.selector);
    stakewiseSplit.rescueFunds(address(vaultToken));
  }

  function test_stakewise_canDistributeWithFee() public {
    deal(address(vaultToken), address(stakewiseSplitWithFee), tokenAmount);
    uint256 prevBalance = vaultToken.balanceOf(demoSplit);

    uint256 amount = stakewiseSplitWithFee.distribute();
    assertTrue(amount > 0, "invalid amount");

    uint256 afterBalance = vaultToken.balanceOf(demoSplit);
    assertGe(afterBalance, prevBalance, "after balance not greater");

    uint256 expectedFee = (tokenAmount * feeShare) / PERCENTAGE_SCALE;
    assertEq(ERC20(vaultToken).balanceOf(feeRecipient), expectedFee, "invalid fee transferred");
    assertEq(vaultToken.balanceOf(demoSplit), tokenAmount - expectedFee, "invalid amount");
  }

  function test_stakewise_fuzzCanDistributeWithFee(
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

    ObolStakewiseSplitFactory fuzzFactorySplitWithFee =
      new ObolStakewiseSplitFactory(fuzzFeeRecipient, fuzzFeeShare);
    ObolStakewiseSplit fuzzSplitWithFee = ObolStakewiseSplit(fuzzFactorySplitWithFee.createSplit(anotherSplit, address(vaultToken)));

    deal(address(vaultToken), address(fuzzSplitWithFee), amountToDistribute);

    uint256 prevBalance = vaultToken.balanceOf(anotherSplit);

    uint256 amount = fuzzSplitWithFee.distribute();
    assertTrue(amount > 0, "invalid amount");

    uint256 afterBalance = vaultToken.balanceOf(anotherSplit);
    assertGe(afterBalance, prevBalance, "after balance not greater");

    uint256 expectedFee = (amountToDistribute * fuzzFeeShare) / PERCENTAGE_SCALE;
    assertEq(vaultToken.balanceOf(fuzzFeeRecipient), expectedFee, "invalid fee transferred");
    assertEq(vaultToken.balanceOf(anotherSplit), amountToDistribute - expectedFee, "invalid amount");
  }
}
