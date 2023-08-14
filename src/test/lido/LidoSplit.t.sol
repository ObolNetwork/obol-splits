// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {LidoSplitFactory, LidoSplit} from "src/lido/LidoSplitFactory.sol";
import {ERC20} from 'solmate/tokens/ERC20.sol';
import {LidoSplitTestHelper} from './LidoSplitTestHelper.sol';

contract MockLidoSplit is LidoSplit {
    function getSplitWallet() public pure returns(address) {
        return _getSplitWallet();
    }

    function getStEthAddress() public pure returns(address) {
        return _getstETHAddress();
    }

    function getWstETHAddress() public pure returns(address) {
        return _getwstETHAddress();
    }
}

contract LidoSplitTest is LidoSplitTestHelper, Test {

    LidoSplitFactory internal lidoSplitFactory;
    LidoSplit internal lidoSplit;

    address demoSplit;

    function setUp() public {
        uint256 mainnetBlock = 17421005;
        vm.createSelectFork(getChain("mainnet").rpcUrl, mainnetBlock);

        lidoSplitFactory = new LidoSplitFactory(
            ERC20(STETH_MAINNET_ADDRESS),
            ERC20(WSTETH_MAINNET_ADDRESS)
        );

        demoSplit = makeAddr("demoSplit");

        lidoSplit = LidoSplit(
            lidoSplitFactory.createSplit(
                demoSplit
            )
        );
    }

    function test_Clone() public {
        MockLidoSplit mockSplit = new MockLidoSplit();
        
    }

    function test_CanDistribute() public {
        deal(address(STETH_MAINNET_ADDRESS), address(lidoSplit), 1 ether);

        lidoSplit.distribute();
    }

}