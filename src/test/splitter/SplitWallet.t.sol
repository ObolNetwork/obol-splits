// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import {SplitFactory} from "src/splitter/SplitFactory.sol";
import {SplitMainV2} from "src/splitter/SplitMainV2.sol";
import {SplitWallet} from "src/splitter/SplitWallet.sol";


contract SplitWalletTest is Test {
    SplitFactory public splitFactory;
    SplitMainV2 public splitMainV2;
    SplitWallet public splitWallet;

    function setUp() public {
        splitFactory = new SplitFactory(address(this));
        splitMainV2 = SplitMainV2(payable(address(splitFactory.splitMain())));
        splitWallet = new SplitWallet(address(splitMainV2));
    }

    function testSendETHToMain() public {

    }

    function testSendERC20ToMain() public {

    }


}