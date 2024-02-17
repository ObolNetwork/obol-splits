// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ObolEthersfiSplitFactory} from "src/ethersfi/ObolEthersfiSplitFactory.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ObolEthersfiSplitTestHelper} from "./ObolEthersfiSplitTestHelper.sol";

contract ObolEthersfiSplitFactoryTest is ObolEthersfiSplitTestHelper, Test {
  ObolEthersfiSplitFactory internal ethersfiSplitFactory;
  ObolEthersfiSplitFactory internal ethersfiSplitFactoryWithFee;

  address demoSplit;

  event CreateObolEthersfiSplit(address split);

  function setUp() public {
    uint256 mainnetBlock = 19_228_949; 
    vm.createSelectFork(getChain("mainnet").rpcUrl, mainnetBlock);

    ethersfiSplitFactory =
      new ObolEthersfiSplitFactory(address(0), 0, ERC20(EETH_MAINNET_ADDRESS), ERC20(WEETH_MAINNET_ADDRESS));

    ethersfiSplitFactoryWithFee =
      new ObolEthersfiSplitFactory(address(this), 1e3, ERC20(EETH_MAINNET_ADDRESS), ERC20(WEETH_MAINNET_ADDRESS));

    demoSplit = makeAddr("demoSplit");
  }

  function testCan_CreateSplit() public {
    vm.expectEmit(true, true, true, false, address(ethersfiSplitFactory));
    emit CreateObolEthersfiSplit(address(0x1));

    ethersfiSplitFactory.createSplit(demoSplit);

    vm.expectEmit(true, true, true, false, address(ethersfiSplitFactoryWithFee));
    emit CreateObolEthersfiSplit(address(0x1));

    ethersfiSplitFactoryWithFee.createSplit(demoSplit);
  }

  function testCannot_CreateSplitInvalidAddress() public {
    vm.expectRevert(ObolEthersfiSplitFactory.Invalid_Wallet.selector);
    ethersfiSplitFactory.createSplit(address(0));

    vm.expectRevert(ObolEthersfiSplitFactory.Invalid_Wallet.selector);
    ethersfiSplitFactoryWithFee.createSplit(address(0));
  }
}
