// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ObolEtherfiSplitFactory} from "src/etherfi/ObolEtherfiSplitFactory.sol";
import {BaseSplitFactory} from "src/base/BaseSplitFactory.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ObolEtherfiSplitTestHelper} from "./ObolEtherfiSplitTestHelper.sol";

contract ObolEtherfiSplitFactoryTest is ObolEtherfiSplitTestHelper, Test {
  ObolEtherfiSplitFactory internal etherfiSplitFactory;
  ObolEtherfiSplitFactory internal etherfiSplitFactoryWithFee;

  address demoSplit;

  event CreateSplit(address token, address split);

  function setUp() public {
    uint256 mainnetBlock = 19_228_949;
    vm.createSelectFork(getChain("mainnet").rpcUrl, mainnetBlock);

    etherfiSplitFactory =
      new ObolEtherfiSplitFactory(address(0), 0, ERC20(EETH_MAINNET_ADDRESS), ERC20(WEETH_MAINNET_ADDRESS));

    etherfiSplitFactoryWithFee =
      new ObolEtherfiSplitFactory(address(this), 1e3, ERC20(EETH_MAINNET_ADDRESS), ERC20(WEETH_MAINNET_ADDRESS));

    demoSplit = makeAddr("demoSplit");
  }

  function testCan_CreateSplit() public {
    vm.expectEmit(true, true, true, false, address(etherfiSplitFactory));
    emit CreateSplit(address(0), address(0x1));

    etherfiSplitFactory.createCollector(address(0), demoSplit);

    vm.expectEmit(true, true, true, false, address(etherfiSplitFactoryWithFee));
    emit CreateSplit(address(0), address(0x1));

    etherfiSplitFactoryWithFee.createCollector(address(0), demoSplit);
  }

  function testCannot_CreateSplitInvalidAddress() public {
    vm.expectRevert(BaseSplitFactory.Invalid_Address.selector);
    etherfiSplitFactory.createCollector(address(0), address(0));

    vm.expectRevert(BaseSplitFactory.Invalid_Address.selector);
    etherfiSplitFactoryWithFee.createCollector(address(0), address(0));
  }
}
