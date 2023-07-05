// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "forge-std/Test.sol";
import {SplitFactory} from "src/splitter/SplitFactory.sol";
import {SplitMainV2} from "src/splitter/SplitMainV2.sol";
import {SplitWallet, Unauthorized} from "src/splitter/SplitWallet.sol";
import {MockERC20} from "../utils/mocks/MockERC20.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";


contract SplitWalletTest is Test {
    SplitFactory public splitFactory;
    SplitMainV2 public splitMainV2;
    SplitWallet public splitWallet;
    MockERC20 mockERC20;

    bytes32 internal splitWalletId = keccak256("splitWallet");

    address splitter;

    address user1;

    event ReceiveETH(uint256 amount);

    function setUp() public {
        user1 = makeAddr("user1");

        mockERC20 = new MockERC20("demo", "DMT", 18);

        splitFactory = new SplitFactory(address(this));
        splitMainV2 = SplitMainV2(payable(address(splitFactory.splitMain())));
        splitWallet = new SplitWallet(address(splitMainV2));
        // add split wallet
        splitFactory.addSplitWallet(splitWalletId, address(splitWallet));

        address[] memory accounts = new address[](2);
        accounts[0] = makeAddr("accounts0");
        accounts[1] = makeAddr("accounts1");

        uint32[] memory percentAllocations = new uint32[](2);
        percentAllocations[0] = 400_000;
        percentAllocations[1] = 600_000;

        splitter = splitFactory.createSplit(
            splitWalletId,
            accounts,
            percentAllocations,
            0,
            address(this),
            address(0)
        );

    }

    function testCanReceiveETH() public {
        uint256 amountOfEth = 10 ether;
        deal(payable(splitter),  amountOfEth);
        assertEq(splitter.balance , amountOfEth);
    }

    function testEmitCorrectEventOnETHReceive() public {
        uint256 amountOfEth = 10 ether;
        vm.expectEmit(false, false, false, false, address(splitter));
        emit ReceiveETH(amountOfEth);

        deal(payable(address(this)), amountOfEth);

        payable(address(splitter)).transfer(amountOfEth);
    }

    function testShouldStoreSplitMainAddress() public {
        assertEq(
            address(SplitWallet(splitter).splitMain()),
            address(splitMainV2)
        );
    }

    function testNonSplitMainCallSendETH() public {
        vm.expectRevert(Unauthorized.selector);
        SplitWallet(splitter).sendETHToMain();
    }

    function testSendETHToSplitMain() public {
        vm.prank(address(splitMainV2));

        uint256 amountOfETHSent = splitter.balance;
        SplitWallet(splitter).sendETHToMain();
        assertEq(address(splitMainV2).balance, amountOfETHSent);
    }

    function testSendERC20ToMain() public {
        uint256 amountOfTokens = 10 ether;
        deal(address(mockERC20), splitter, amountOfTokens);

        vm.prank(address(splitMainV2));

        SplitWallet(splitter).sendERC20ToMain(ERC20(address(mockERC20)));

        assertEq(
            mockERC20.balanceOf(address(splitMainV2)),
            amountOfTokens
        );
    }

    function testNonSplitMainCallSendERC20ToMain() public {
        vm.expectRevert(Unauthorized.selector);
        SplitWallet(splitter).sendERC20ToMain(ERC20(address(mockERC20)));
    }

}