// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {LidoSplitFactory} from "src/lido/LidoSplitFactory.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {LidoSplitTestHelper} from "./LidoSplitTestHelper.sol";

contract LidoSplitFactoryTest is LidoSplitTestHelper, Test {
  LidoSplitFactory internal lidoSplitFactory;
  LidoSplitFactory internal lidoSplitFactoryWithFee;

  address demoSplit;

  event CreateLidoSplit(address split);

  function setUp() public {
    uint256 mainnetBlock = 17_421_005;
    vm.createSelectFork(getChain("mainnet").rpcUrl, mainnetBlock);

    lidoSplitFactory = new LidoSplitFactory(
      address(0),
      0,
      ERC20(STETH_MAINNET_ADDRESS),
      ERC20(WSTETH_MAINNET_ADDRESS)
    );

    lidoSplitFactoryWithFee = new LidoSplitFactory(
      address(this),
      1e3,
      ERC20(STETH_MAINNET_ADDRESS),
      ERC20(WSTETH_MAINNET_ADDRESS)
    );

    demoSplit = makeAddr("demoSplit");
  }

  function testCan_CreateSplit() public {
    vm.expectEmit(true, true, true, false, address(lidoSplitFactory));
    emit CreateLidoSplit(address(0x1));

    lidoSplitFactory.createSplit(demoSplit);


    vm.expectEmit(true, true, true, false, address(lidoSplitFactoryWithFee));
    emit CreateLidoSplit(address(0x1));

    lidoSplitFactoryWithFee.createSplit(demoSplit);
  }

  function testCannot_CreateSplitInvalidAddress() public {
    vm.expectRevert(LidoSplitFactory.Invalid_Wallet.selector);
    lidoSplitFactory.createSplit(address(0));

    vm.expectRevert(LidoSplitFactory.Invalid_Wallet.selector);
    lidoSplitFactoryWithFee.createSplit(address(0));
  }
}
