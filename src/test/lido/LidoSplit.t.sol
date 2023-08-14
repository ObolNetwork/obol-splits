// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {LidoSplitFactory} from "src/lido/LidoSplitFactory.sol";
import {ERC20} from 'solmate/tokens/ERC20.sol';
import {LidoSplitTestHelper} from './LidoSplitTestHelper.sol';

contract LidoSplitTest is LidoSplitTestHelper, Test {

    LidoSplitFactory internal lidoSplitFactory;

    address demoSplit;

    function setUp() public {
        uint256 mainnetBlock = 17421005;
        vm.createSelectFork(getChain("mainnet").rpcUrl, mainnetBlock);

        lidoSplitFactory = new LidoSplitFactory(
            ERC20(STETH_MAINNET_ADDRESS),
            ERC20(WSTETH_MAINNET_ADDRESS)
        );

        demoSplit = makeAddr("demoSplit");
    }

    function test_Distribute() public {
        
    }

}