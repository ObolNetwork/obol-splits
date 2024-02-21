// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ObolEtherfiSplitFactory} from "src/etherfi/ObolEtherfiSplitFactory.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ObolEtherfiSplitTestHelper} from "./ObolEtherfiSplitTestHelper.sol";

contract ObolEtherfiSplitFactoryTest is ObolEtherfiSplitTestHelper, Test {
  ObolEtherfiSplitFactory internal etherfiSplitFactory;
  ObolEtherfiSplitFactory internal etherfiSplitFactoryWithFee;

  address demoSplit;

  event CreateObolEtherfiSplit(address split);

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
    emit CreateObolEtherfiSplit(address(0x1));

    etherfiSplitFactory.createSplit(demoSplit);

    vm.expectEmit(true, true, true, false, address(etherfiSplitFactoryWithFee));
    emit CreateObolEtherfiSplit(address(0x1));

    etherfiSplitFactoryWithFee.createSplit(demoSplit);
  }

  function testCannot_CreateSplitInvalidAddress() public {
    vm.expectRevert(ObolEtherfiSplitFactory.Invalid_Wallet.selector);
    etherfiSplitFactory.createSplit(address(0));

    vm.expectRevert(ObolEtherfiSplitFactory.Invalid_Wallet.selector);
    etherfiSplitFactoryWithFee.createSplit(address(0));
  }
}
