// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {LidoSplitFactory, LidoSplit} from "src/lido/LidoSplitFactory.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {LidoSplitTestHelper} from "./LidoSplitTestHelper.sol";
import { MockERC20 } from "src/test/utils/mocks/MockERC20.sol";


contract LidoSplitTest is LidoSplitTestHelper, Test {
  LidoSplitFactory internal lidoSplitFactory;
  LidoSplit internal lidoSplit;

  address demoSplit;

  MockERC20 mERC20;

  function setUp() public {
    uint256 mainnetBlock = 17_421_005;
    vm.createSelectFork(getChain("mainnet").rpcUrl, mainnetBlock);

    lidoSplitFactory = new LidoSplitFactory(
            ERC20(STETH_MAINNET_ADDRESS),
            ERC20(WSTETH_MAINNET_ADDRESS)
        );

    demoSplit = makeAddr("demoSplit");

    lidoSplit = LidoSplit(lidoSplitFactory.createSplit(demoSplit));
    
    mERC20 = new MockERC20("Test Token", "TOK", 18);
    mERC20.mint(type(uint256).max);
  }

  function test_CloneArgsIsCorrect() public {
    assertEq(lidoSplit.splitWallet(), demoSplit, "invalid address");
    assertEq(address(lidoSplit.stETH()), STETH_MAINNET_ADDRESS, "invalid stETH address");
    assertEq(address(lidoSplit.wstETH()), WSTETH_MAINNET_ADDRESS, "invalid wstETH address");
  }

  function test_CanRescueFunds() public {
    // rescue ETH
    uint256 amountOfEther = 1 ether;
    deal(address(lidoSplit), amountOfEther);

    uint256 balance = lidoSplit.rescueFunds(address(0));
    assertEq(balance, amountOfEther, "balance not rescued");
    assertEq(address(lidoSplit).balance, 0, "balance is not zero");
    assertEq(address(lidoSplit.splitWallet()).balance, amountOfEther, "rescue not successful");

    // rescue tokens
    mERC20.transfer(address(lidoSplit), amountOfEther);
    uint256 tokenBalance = lidoSplit.rescueFunds(address(mERC20));
    assertEq(tokenBalance, amountOfEther, "token - balance not rescued");
    assertEq(mERC20.balanceOf(address(lidoSplit)), 0, "token - balance is not zero");
    assertEq(mERC20.balanceOf(lidoSplit.splitWallet()), amountOfEther, "token - rescue not successful");
  }

  function testCannot_RescueLidoTokens() public {
    vm.expectRevert(
      LidoSplit.Invalid_Address.selector
    );
    lidoSplit.rescueFunds(address(STETH_MAINNET_ADDRESS));

    vm.expectRevert(
      LidoSplit.Invalid_Address.selector
    );
    lidoSplit.rescueFunds(address(WSTETH_MAINNET_ADDRESS));
  }

  function test_CanDistribute() public {
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
}
