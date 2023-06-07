// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;
import "forge-std/Test.sol";
import {ERC20} from '@rari-capital/solmate/src/tokens/ERC20.sol';
import "../../../lido/LidoSplitWallet.sol";

contract LidoIntegration is Test {
    
    address internal STETH_MAINNET_ADDRESS = '0x';
    address internal WSTETH_MAINNET_ADDRESS = '0x';

    LidoSplitWallet lidoSplitWallet;

    function setUp() {
        uint256 mainnetBlock = 17421005;
        vm.createSelectFork(getChain("mainnet").rpcUrl, mainnetBlock);

        lidoSplitWallet = new LidoSplitWallet(
            ERC20(STETH_MAINNET_ADDRESS),
            ERC20(WSTETH_MAINNET_ADDRESS)
        );
    }

    function testSendERC20ToMain() external {
        deal(STETH_MAINNET_ADDRESS, lidoSplitWallet, 1 ether);

        uint256 amount = lidoSplitWallet.sendERC20ToMain(ERC20(wstETH));

        // check the balance of this address
        assertEq(
            ERC20(WSTETH_MAINNET_ADDRESS).balanceOf(address(this)),
            amount
        );
    }


    function testSendETHToMain() external {
        vm.deal(lidoSplitWallet, 1 ether);

        uint256 amount = lidoSplitWallet.sendETHToMain();

        // check the balance of this address
        assertEq(address(this).balance, amount);
    }
}