// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {LidoSplitFactory} from "src/lido/LidoSplitFactory.sol";
import {ERC20} from 'solmate/tokens/ERC20.sol';
import {LidoSplitTestHelper} from './LidoSplitTestHelper.sol';

contract LidoSplitFactoryTest is LidoSplitTestHelper, Test {

    LidoSplitFactory internal lidoSplitFactory;

    address demoSplit;

    event CreateLidoSplit(
        address split
    );

    function setUp() public {
        uint256 mainnetBlock = 17421005;
        vm.createSelectFork(getChain("mainnet").rpcUrl, mainnetBlock);

        lidoSplitFactory = new LidoSplitFactory(
            ERC20(STETH_MAINNET_ADDRESS),
            ERC20(WSTETH_MAINNET_ADDRESS)
        );

        demoSplit = makeAddr("demoSplit");
    }

    function testCan_CreateSplit() public {
        
        vm.expectEmit(true, true, true, true, address(lidoSplitFactory));
        emit CreateLidoSplit(demoSplit);
        
        lidoSplitFactory.createSplit(demoSplit);
    }

    function testCannot_CreateSplitInvalidAddress() public {
        vm.expectRevert(LidoSplitFactory.Invalid_Wallet.selector);
        lidoSplitFactory.createSplit(address(0));
    }
}