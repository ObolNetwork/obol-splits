// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {LidoSplitFactory, LidoSplit} from "src/lido/LidoSplitFactory.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {LidoSplitTestHelper} from "./LidoSplitTestHelper.sol";

contract LidoSplitTest is LidoSplitTestHelper, Test {
  LidoSplitFactory internal lidoSplitFactory;
  LidoSplit internal lidoSplit;

  address demoSplit;

  function setUp() public {
    uint256 mainnetBlock = 17_421_005;
    vm.createSelectFork(getChain("mainnet").rpcUrl, mainnetBlock);

    lidoSplitFactory = new LidoSplitFactory(
            ERC20(STETH_MAINNET_ADDRESS),
            ERC20(WSTETH_MAINNET_ADDRESS)
        );

    demoSplit = makeAddr("demoSplit");

    lidoSplit = LidoSplit(lidoSplitFactory.createSplit(demoSplit));
  }

  function test_CloneArgsIsCorrect() public {
    assertEq(lidoSplit.splitWallet(), demoSplit, "invalid address");
    assertEq(address(lidoSplit.stETH()), STETH_MAINNET_ADDRESS, "invalid stETH address");
    assertEq(address(lidoSplit.wstETH()), WSTETH_MAINNET_ADDRESS, "invalid wstETH address");
  }

  function test_CanRescueETH() public {
    deal(lidoSplit.splitWallet(), 1 ether);

    
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
