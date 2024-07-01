// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ObolLidoSplitFactory} from "src/lido/ObolLidoSplitFactory.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {BaseSplitFactory} from "src/base/BaseSplitFactory.sol";
import {ObolLidoSplitTestHelper} from "./ObolLidoSplitTestHelper.sol";

contract ObolLidoSplitFactoryTest is ObolLidoSplitTestHelper, Test {
  ObolLidoSplitFactory internal lidoSplitFactory;
  ObolLidoSplitFactory internal lidoSplitFactoryWithFee;

  address demoSplit;

  event CreateSplit(address token, address split);

  function setUp() public {
    uint256 mainnetBlock = 17_421_005;
    vm.createSelectFork(getChain("mainnet").rpcUrl, mainnetBlock);

    lidoSplitFactory =
      new ObolLidoSplitFactory(address(0), 0, ERC20(STETH_MAINNET_ADDRESS), ERC20(WSTETH_MAINNET_ADDRESS));

    lidoSplitFactoryWithFee =
      new ObolLidoSplitFactory(address(this), 1e3, ERC20(STETH_MAINNET_ADDRESS), ERC20(WSTETH_MAINNET_ADDRESS));

    demoSplit = makeAddr("demoSplit");
  }

  function testCan_CreateSplit() public {
    vm.expectEmit(true, true, true, false, address(lidoSplitFactory));
    emit CreateSplit(address(0), address(0x1));

    lidoSplitFactory.createCollector(address(0), demoSplit);

    vm.expectEmit(true, true, true, false, address(lidoSplitFactoryWithFee));
    emit CreateSplit(address(0), address(0x1));

    lidoSplitFactoryWithFee.createCollector(address(0), demoSplit);
  }

  function testCannot_CreateSplitInvalidAddress() public {
    vm.expectRevert(BaseSplitFactory.Invalid_Address.selector);
    lidoSplitFactory.createCollector(address(0), address(0));

    vm.expectRevert(BaseSplitFactory.Invalid_Address.selector);
    lidoSplitFactoryWithFee.createCollector(address(0), address(0));
  }
}
