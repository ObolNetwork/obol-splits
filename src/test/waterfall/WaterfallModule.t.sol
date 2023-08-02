// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import { WaterfallModule } from "src/waterfall/WaterfallModule.sol";
import { WaterfallModuleFactory } from "src/waterfall/WaterfallModuleFactory.sol";
import {MockERC20} from "../utils/mocks/MockERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {WaterfallTestHelper} from "./WaterfallTestHelper.t.sol";

contract WaterfallModuleTest is WaterfallTestHelper, Test {
    using SafeTransferLib for address;

    event CreateWaterfallModule(
        address indexed waterfallModule,
        address token,
        address nonWaterfallRecipient,
        address[] trancheRecipients,
        uint256[] trancheThresholds
    );

    event ReceiveETH(uint256 amount);

    event WaterfallFunds(
        address[] recipients, uint256[] payouts, uint256 pullFlowFlag
    );

    event RecoverNonWaterfallFunds(
        address nonWaterfallToken, address recipient, uint256 amount
    );

    WaterfallModule public waterfallModule;
    WaterfallModuleFactory public waterfallModuleFactory;
    address public nonWaterfallRecipient;

    WaterfallModule waterfallModuleETH;
    WaterfallModule waterfallModuleERC20;
    WaterfallModule waterfallModuleETH_OR;
    WaterfallModule waterfallModuleERC20_OR;
    MockERC20 mERC20;

    address[] internal trancheRecipients;
    uint256 internal trancheThreshold;

    function setUp() public {
        waterfallModuleFactory = new WaterfallModuleFactory();
        waterfallModule = waterfallModuleFactory.wmImpl();

        mERC20 = new MockERC20("demo", "DMT", 18);
        mERC20.mint(type(uint256).max);

        trancheRecipients = generateTrancheRecipients(2, uint256(uint160(makeAddr("tranche"))));
        // use 1 validator as default tranche threshold
        trancheThreshold = ETH_STAKE;

        nonWaterfallRecipient = makeAddr("nonWaterfallRecipient");

        waterfallModuleETH = waterfallModuleFactory.createWaterfallModule(
            ETH_ADDRESS,
            nonWaterfallRecipient,
            trancheRecipients,
            trancheThreshold
        );

        waterfallModuleERC20 = waterfallModuleFactory.createWaterfallModule(
            address(mERC20),
            nonWaterfallRecipient,
            trancheRecipients,
            trancheThreshold
        );

        waterfallModuleETH_OR = waterfallModuleFactory.createWaterfallModule(
            ETH_ADDRESS, address(0), trancheRecipients, trancheThreshold
        );
        waterfallModuleERC20_OR = waterfallModuleFactory.createWaterfallModule(
            address(mERC20), address(0), trancheRecipients, trancheThreshold
        );
    }

    // function testP() public {
    //     console.logString("checking");
    //     console.log(type(uint96).max);
    //     console.log(type(uint96).max / 1 ether);
    //     console.log(type(uint96).max / 32 ether);
    // }

    function testGetTranches() public {
        (address[] memory wtrancheRecipients, uint256 wtrancheThreshold)
        = waterfallModuleETH.getTranches();

        for (uint256 i = 0; i < wtrancheRecipients.length; i++) {
            assertEq(wtrancheRecipients[i], trancheRecipients[i]);
        }
        
        assertEq(wtrancheThreshold, ETH_STAKE, "invalid eth tranche threshold");
        
        (wtrancheRecipients, wtrancheThreshold) = waterfallModuleERC20.getTranches();
        for (uint256 i = 0; i < wtrancheRecipients.length; i++) {
            assertEq(wtrancheRecipients[i], trancheRecipients[i]);
        }
        
        assertEq(wtrancheThreshold, ETH_STAKE, "invalid erc20 tranche threshold");
    }

    function testReceiveETH() public {
        address(waterfallModuleETH).safeTransferETH(1 ether);
        assertEq(address(waterfallModuleETH).balance, 1 ether);

        address(waterfallModuleERC20).safeTransferETH(1 ether);
        assertEq(address(waterfallModuleERC20).balance, 1 ether);
    }

    function testReceiveTransfer() public {
        payable(address(waterfallModuleETH)).transfer(1 ether);
        assertEq(address(waterfallModuleETH).balance, 1 ether);

        payable(address(waterfallModuleERC20)).transfer(1 ether);
        assertEq(address(waterfallModuleERC20).balance, 1 ether);
    }

    function testEmitOnReceiveETH() public {
        vm.expectEmit(true, true, true, true);
        emit ReceiveETH(1 ether);

        address(waterfallModuleETH).safeTransferETH(1 ether);
    }

    function testReceiveERC20() public {       
        address(mERC20).safeTransfer(address(waterfallModuleETH), 1 ether);
        assertEq(mERC20.balanceOf(address(waterfallModuleETH)), 1 ether);

        address(mERC20).safeTransfer(address(waterfallModuleERC20), 1 ether);
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20)), 1 ether);
    }

    function testCan_recoverNonWaterfallFundsToRecipient() public {
        address(waterfallModuleETH).safeTransferETH(1 ether);
        address(mERC20).safeTransfer(address(waterfallModuleETH), 1 ether);
        address(waterfallModuleETH_OR).safeTransferETH(1 ether);
        address(mERC20).safeTransfer(address(waterfallModuleETH_OR), 1 ether);

        vm.expectEmit(true, true, true, true);
        emit RecoverNonWaterfallFunds(
            address(mERC20), nonWaterfallRecipient, 1 ether
        );
        waterfallModuleETH.recoverNonWaterfallFunds(address(mERC20), nonWaterfallRecipient);
        assertEq(address(waterfallModuleETH).balance, 1 ether);
        assertEq(mERC20.balanceOf(address(waterfallModuleETH)), 0 ether);
        assertEq(mERC20.balanceOf(nonWaterfallRecipient), 1 ether);

        vm.expectEmit(true, true, true, true);
        emit RecoverNonWaterfallFunds(
            address(mERC20), trancheRecipients[0], 1 ether
        );
        waterfallModuleETH_OR.recoverNonWaterfallFunds(address(mERC20), trancheRecipients[0]);
        assertEq(address(waterfallModuleETH_OR).balance, 1 ether);
        assertEq(mERC20.balanceOf(address(waterfallModuleETH_OR)), 0 ether);
        assertEq(mERC20.balanceOf(trancheRecipients[0]), 1 ether);

        address(mERC20).safeTransfer(address(waterfallModuleETH_OR), 1 ether);

        vm.expectEmit(true, true, true, true);
        emit RecoverNonWaterfallFunds(
            address(mERC20), trancheRecipients[1], 1 ether
        );
        waterfallModuleETH_OR.recoverNonWaterfallFunds(address(mERC20), trancheRecipients[1]);
        assertEq(address(waterfallModuleETH_OR).balance, 1 ether);
        assertEq(mERC20.balanceOf(address(waterfallModuleETH_OR)), 0 ether);
        assertEq(mERC20.balanceOf(trancheRecipients[1]), 1 ether);
        
 
        address(waterfallModuleERC20).safeTransferETH(1 ether);
        address(mERC20).safeTransfer(address(waterfallModuleERC20), 1 ether);

        
        vm.expectEmit(true, true, true, true);
        emit RecoverNonWaterfallFunds(
            ETH_ADDRESS, nonWaterfallRecipient, 1 ether
        );
        waterfallModuleERC20.recoverNonWaterfallFunds(ETH_ADDRESS, nonWaterfallRecipient);
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20)), 1 ether);
        assertEq(address(waterfallModuleERC20).balance, 0 ether);
        assertEq(nonWaterfallRecipient.balance, 1 ether);


        address(waterfallModuleERC20_OR).safeTransferETH(1 ether);
        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 1 ether);

        vm.expectEmit(true, true, true, true);
        emit RecoverNonWaterfallFunds(
            ETH_ADDRESS, trancheRecipients[0], 1 ether
        );
        waterfallModuleERC20_OR.recoverNonWaterfallFunds(ETH_ADDRESS, trancheRecipients[0]);
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 1 ether);
        assertEq(address(waterfallModuleERC20_OR).balance, 0 ether);
        assertEq(trancheRecipients[0].balance, 1 ether);

        address(waterfallModuleERC20_OR).safeTransferETH(1 ether);

        waterfallModuleERC20_OR.recoverNonWaterfallFunds(ETH_ADDRESS, trancheRecipients[1]);
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 1 ether);
        assertEq(address(waterfallModuleERC20_OR).balance, 0 ether, "invalid erc20 balance");
        assertEq(trancheRecipients[1].balance, 1 ether, "invalid eth balance");
    }

    function testCannot_recoverNonWaterfallFundsToNonRecipient() public {
        vm.expectRevert(
            WaterfallModule.InvalidTokenRecovery_InvalidRecipient.selector
        );
        waterfallModuleETH.recoverNonWaterfallFunds(address(mERC20), address(1));

        vm.expectRevert(
            WaterfallModule.InvalidTokenRecovery_InvalidRecipient.selector
        );
        waterfallModuleERC20_OR.recoverNonWaterfallFunds(ETH_ADDRESS, address(1));

        vm.expectRevert(
            WaterfallModule.InvalidTokenRecovery_InvalidRecipient.selector
        );
        waterfallModuleETH_OR.recoverNonWaterfallFunds(address(mERC20), address(2));

        vm.expectRevert(
            WaterfallModule.InvalidTokenRecovery_InvalidRecipient.selector
        );
        waterfallModuleERC20_OR.recoverNonWaterfallFunds(ETH_ADDRESS, address(2));
    }

    function testCannot_recoverWaterfallFunds() public {
        vm.expectRevert(
            WaterfallModule.InvalidTokenRecovery_WaterfallToken.selector
        );
        waterfallModuleETH.recoverNonWaterfallFunds(ETH_ADDRESS, nonWaterfallRecipient);

        vm.expectRevert(
            WaterfallModule.InvalidTokenRecovery_WaterfallToken.selector
        );
        waterfallModuleERC20_OR.recoverNonWaterfallFunds(address(mERC20), nonWaterfallRecipient);

        vm.expectRevert(
            WaterfallModule.InvalidTokenRecovery_WaterfallToken.selector
        );
        waterfallModuleETH_OR.recoverNonWaterfallFunds(ETH_ADDRESS, address(1));

        vm.expectRevert(
            WaterfallModule.InvalidTokenRecovery_WaterfallToken.selector
        );
        waterfallModuleERC20_OR.recoverNonWaterfallFunds(address(mERC20), address(1));
    }

    function testCan_waterfallIsPayable() public {
        waterfallModuleETH.waterfallFunds{value: 2 ether}();

        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(trancheRecipients[0].balance, 0);
        assertEq(trancheRecipients[1].balance, 2 ether);
    }

    function testCan_waterfallToNoRecipients() public {
        waterfallModuleETH.waterfallFunds();
        assertEq(trancheRecipients[0].balance, 0 ether);

        waterfallModuleERC20_OR.waterfallFunds();
        assertEq(mERC20.balanceOf(trancheRecipients[0]), 0 ether);
    }

    function testCan_emitOnWaterfallToNoRecipients() public {
        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 0 ether;
        payouts[1] = 0 ether;

        vm.expectEmit(true, true, true, true);
        emit WaterfallFunds(trancheRecipients, payouts, 0);
        waterfallModuleETH.waterfallFunds();
    }

    function testCan_waterfallToSecondRecipient() public {
        address(waterfallModuleETH).safeTransferETH(1 ether);
        
        uint256[] memory payouts = new uint256[](2);
        payouts[1] = 1 ether;

        vm.expectEmit(true, true, true, true);
        emit WaterfallFunds(trancheRecipients, payouts, 0);
        waterfallModuleETH.waterfallFunds();
        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(trancheRecipients[1].balance, 1 ether);

        payouts[1] = 0;    
        vm.expectEmit(true, true, true, true);
        emit WaterfallFunds(trancheRecipients, payouts, 0);
        waterfallModuleETH.waterfallFunds();
        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(trancheRecipients[0].balance, 0 ether);
        assertEq(trancheRecipients[1].balance, 1 ether);

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 1 ether);

        payouts[1] = 1 ether;    
        vm.expectEmit(true, true, true, true);
        emit WaterfallFunds(trancheRecipients, payouts, 0);
        waterfallModuleERC20_OR.waterfallFunds();
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0 ether);
        assertEq(mERC20.balanceOf(trancheRecipients[1]), 1 ether);

        payouts[1] = 0;    
        vm.expectEmit(true, true, true, true);
        emit WaterfallFunds(trancheRecipients, payouts, 0);
        waterfallModuleERC20_OR.waterfallFunds();
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0 ether);
        assertEq(trancheRecipients[0].balance, 0 ether);
        assertEq(trancheRecipients[1].balance, 1 ether);
    }

    function testCan_waterfallMultipleDepositsToRewardRecipient() public {
        address(waterfallModuleETH).safeTransferETH(0.5 ether);
        waterfallModuleETH.waterfallFunds();
        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(trancheRecipients[1].balance, 0.5 ether);

        address(waterfallModuleETH).safeTransferETH(0.5 ether);
        waterfallModuleETH.waterfallFunds();
        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(trancheRecipients[1].balance, 1 ether);

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 0.5 ether);
        waterfallModuleERC20_OR.waterfallFunds();
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0 ether);
        assertEq(mERC20.balanceOf(trancheRecipients[1]), 0.5 ether);

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 0.5 ether);
        waterfallModuleERC20_OR.waterfallFunds();
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0 ether);
        assertEq(mERC20.balanceOf(trancheRecipients[1]), 1 ether);
    }

    function testCan_waterfallToBothRecipients() public {
        address(waterfallModuleETH).safeTransferETH(36 ether);

        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 32 ether;
        payouts[1] = 4 ether;

        vm.expectEmit(true, true, true, true);
        emit WaterfallFunds(trancheRecipients, payouts, 0);
        waterfallModuleETH.waterfallFunds();
        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(trancheRecipients[0].balance, 32 ether);
        assertEq(trancheRecipients[1].balance, 4 ether);

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 36 ether);
        
        vm.expectEmit(true, true, true, true);
        emit WaterfallFunds(trancheRecipients, payouts, 0);
        waterfallModuleERC20_OR.waterfallFunds();
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0 ether);
        assertEq(trancheRecipients[0].balance, 32 ether);
        assertEq(trancheRecipients[1].balance, 4 ether);
    }

    function testCan_waterfallMultipleDepositsToPrincipalRecipient() public {
        address(waterfallModuleETH).safeTransferETH(16 ether);
        waterfallModuleETH.waterfallFunds();

        address(waterfallModuleETH).safeTransferETH(16 ether);
        waterfallModuleETH.waterfallFunds();

        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(trancheRecipients[0].balance, 32 ether);
        assertEq(trancheRecipients[1].balance, 0 ether);

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 16 ether);
        waterfallModuleERC20_OR.waterfallFunds();

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 16 ether);
        waterfallModuleERC20_OR.waterfallFunds();

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0 ether);
        assertEq(mERC20.balanceOf(trancheRecipients[0]), 32 ether);
        assertEq(mERC20.balanceOf(trancheRecipients[1]), 0);
    }

    function testCannot_distributeTooMuch() public {
        vm.deal(address(waterfallModuleETH), type(uint128).max);
        waterfallModuleETH.waterfallFunds();
        vm.deal(address(waterfallModuleETH), 1);

        vm.expectRevert(WaterfallModule.InvalidDistribution_TooLarge.selector);
        waterfallModuleETH.waterfallFunds();

        vm.expectRevert(WaterfallModule.InvalidDistribution_TooLarge.selector);
        waterfallModuleETH.waterfallFundsPull();

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), type(uint128).max);
        waterfallModuleERC20_OR.waterfallFunds();
        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 1);

        vm.expectRevert(WaterfallModule.InvalidDistribution_TooLarge.selector);
        waterfallModuleERC20_OR.waterfallFunds();

        vm.expectRevert(WaterfallModule.InvalidDistribution_TooLarge.selector);
        waterfallModuleERC20_OR.waterfallFundsPull();
    }

    // // function testCannot_reenterWaterfall() public {
    // //     WaterfallReentrancy wr = new WaterfallReentrancy();

    // //     uint256 _trancheRecipientsLength = 2;
    // //     address[] memory _trancheRecipients =
    // //         new address[](_trancheRecipientsLength);
    // //     _trancheRecipients[0] = address(wr);
    // //     _trancheRecipients[1] = address(0);
    // //     uint256 _trancheThresholdsLength = _trancheRecipientsLength - 1;
    // //     uint256[] memory _trancheThresholds =
    // //         new uint256[](_trancheThresholdsLength);
    // //     _trancheThresholds[0] = 1 ether;

    // //     waterfallModuleETH = wmf.createWaterfallModule(
    // //         ETH_ADDRESS,
    // //         nonWaterfallRecipient,
    // //         _trancheRecipients,
    // //         _trancheThresholds
    // //     );
    // //     address(waterfallModuleETH).safeTransferETH(10 ether);
    // //     vm.expectRevert(SafeTransferLib.ETHTransferFailed.selector);
    // //     waterfallModuleETH.waterfallFunds();
    // //     assertEq(address(waterfallModuleETH).balance, 10 ether);
    // //     assertEq(address(wr).balance, 0 ether);
    // //     assertEq(address(0).balance, 0 ether);
    // // }

    function testCan_waterfallToPullFlow() public {
        // test eth
        address(waterfallModuleETH).safeTransferETH(36 ether);
        waterfallModuleETH.waterfallFundsPull();

        assertEq(address(waterfallModuleETH).balance, 36 ether);
        assertEq(trancheRecipients[0].balance, 0 ether);
        assertEq(trancheRecipients[1].balance, 0 ether);

        assertEq(waterfallModuleETH.getPullBalance(trancheRecipients[0]), 32 ether);
        assertEq(waterfallModuleETH.getPullBalance(trancheRecipients[1]), 4 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 36 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 36 ether);

        waterfallModuleETH.withdraw(trancheRecipients[1]);

        assertEq(address(waterfallModuleETH).balance, 32 ether);
        assertEq(trancheRecipients[0].balance, 0);
        assertEq(trancheRecipients[1].balance, 4 ether);

        assertEq(waterfallModuleETH.getPullBalance(trancheRecipients[0]), 32 ether);
        assertEq(waterfallModuleETH.getPullBalance(trancheRecipients[1]), 0);

        assertEq(waterfallModuleETH.distributedFunds(), 36 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 32 ether);

        waterfallModuleETH.withdraw(trancheRecipients[0]);

        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(trancheRecipients[0].balance, 32 ether);
        assertEq(trancheRecipients[1].balance, 4 ether);

        assertEq(waterfallModuleETH.getPullBalance(trancheRecipients[0]), 0);
        assertEq(waterfallModuleETH.getPullBalance(trancheRecipients[1]), 0);

        assertEq(waterfallModuleETH.distributedFunds(), 36 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 0 ether);

        // test erc20
        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 36 ether);
        waterfallModuleERC20_OR.waterfallFundsPull();

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 36 ether);
        assertEq(mERC20.balanceOf(trancheRecipients[0]), 0);
        assertEq(mERC20.balanceOf(trancheRecipients[1]), 0);

        assertEq(waterfallModuleERC20_OR.getPullBalance(trancheRecipients[0]), 32 ether);
        assertEq(waterfallModuleERC20_OR.getPullBalance(trancheRecipients[1]), 4 ether);

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 36 ether);
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 36 ether);

        waterfallModuleERC20_OR.withdraw(trancheRecipients[1]);

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 32 ether);
        assertEq(mERC20.balanceOf(trancheRecipients[0]), 0 ether);
        assertEq(mERC20.balanceOf(trancheRecipients[1]), 4 ether);

        assertEq(waterfallModuleERC20_OR.getPullBalance(trancheRecipients[0]), 32 ether);
        assertEq(waterfallModuleERC20_OR.getPullBalance(trancheRecipients[1]), 0 ether);

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 36 ether);
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 32 ether);

        waterfallModuleERC20_OR.withdraw(trancheRecipients[0]);

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0 ether);
        assertEq(mERC20.balanceOf(trancheRecipients[0]), 32 ether);
        assertEq(mERC20.balanceOf(trancheRecipients[1]), 4 ether);

        assertEq(waterfallModuleERC20_OR.getPullBalance(trancheRecipients[0]), 0 ether);
        assertEq(waterfallModuleERC20_OR.getPullBalance(trancheRecipients[1]), 0 ether);

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 36 ether);
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 0 ether);
    }

    function testCan_waterfallPushAndPull() public {
        // test eth
        address(waterfallModuleETH).safeTransferETH(0.5 ether);
        assertEq(address(waterfallModuleETH).balance, 0.5 ether, "incorrect waterfall balance");

        waterfallModuleETH.waterfallFunds();

        assertEq(address(waterfallModuleETH).balance, 0, "incorrect balance");
        assertEq(trancheRecipients[0].balance, 0 ether);
        assertEq(trancheRecipients[1].balance, 0.5 ether);

        assertEq(waterfallModuleETH.getPullBalance(trancheRecipients[0]), 0 ether);
        assertEq(waterfallModuleETH.getPullBalance(trancheRecipients[1]), 0 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 0.5 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 0 ether);

        address(waterfallModuleETH).safeTransferETH(1 ether);
        assertEq(address(waterfallModuleETH).balance, 1 ether);

        waterfallModuleETH.waterfallFundsPull();

        assertEq(address(waterfallModuleETH).balance, 1 ether);
        assertEq(trancheRecipients[0].balance, 0 ether);
        assertEq(trancheRecipients[1].balance, 0.5 ether);

        assertEq(waterfallModuleETH.getPullBalance(trancheRecipients[0]), 0 ether);
        assertEq(waterfallModuleETH.getPullBalance(trancheRecipients[1]), 1 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 1.5 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 1 ether);

        waterfallModuleETH.waterfallFunds();

        assertEq(address(waterfallModuleETH).balance, 1 ether);
        assertEq(trancheRecipients[0].balance, 0 ether);
        assertEq(trancheRecipients[1].balance, 0.5 ether);

        assertEq(waterfallModuleETH.getPullBalance(trancheRecipients[0]), 0);
        assertEq(waterfallModuleETH.getPullBalance(trancheRecipients[1]), 1 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 1.5 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 1 ether);

        waterfallModuleETH.waterfallFundsPull();

        assertEq(address(waterfallModuleETH).balance, 1 ether);
        assertEq(trancheRecipients[0].balance, 0 ether);
        assertEq(trancheRecipients[1].balance, 0.5 ether);

        assertEq(waterfallModuleETH.getPullBalance(trancheRecipients[0]), 0);
        assertEq(waterfallModuleETH.getPullBalance(trancheRecipients[1]), 1 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 1.5 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 1 ether);

        address(waterfallModuleETH).safeTransferETH(1 ether);
        assertEq(address(waterfallModuleETH).balance, 2 ether);

        waterfallModuleETH.waterfallFunds();

        assertEq(address(waterfallModuleETH).balance, 1 ether);
        assertEq(trancheRecipients[0].balance, 0);
        assertEq(trancheRecipients[1].balance, 1.5 ether);

        assertEq(waterfallModuleETH.getPullBalance(trancheRecipients[0]), 0 ether);
        assertEq(waterfallModuleETH.getPullBalance(trancheRecipients[1]), 1 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 2.5 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 1 ether);

        waterfallModuleETH.withdraw(trancheRecipients[1]);

        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(trancheRecipients[0].balance, 0);
        assertEq(trancheRecipients[1].balance, 2.5 ether);

        assertEq(waterfallModuleETH.getPullBalance(trancheRecipients[0]), 0 ether);
        assertEq(waterfallModuleETH.getPullBalance(trancheRecipients[1]), 0 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 2.5 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 0);
        
        address(waterfallModuleETH).safeTransferETH(1 ether);
        waterfallModuleETH.withdraw(trancheRecipients[1]);

        assertEq(address(waterfallModuleETH).balance, 1 ether);
        assertEq(trancheRecipients[0].balance, 0 ether);
        assertEq(trancheRecipients[1].balance, 2.5 ether);

        assertEq(waterfallModuleETH.getPullBalance(trancheRecipients[0]), 0 ether);
        assertEq(waterfallModuleETH.getPullBalance(trancheRecipients[1]), 0 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 2.5 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 0 ether);

        // TEST ERC20

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 0.5 ether);
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0.5 ether);

        waterfallModuleERC20_OR.waterfallFunds();

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0 ether, "1/invalid waterfall balance");
        assertEq(mERC20.balanceOf(trancheRecipients[0]), 0 ether, "2/invalid tranche 1 recipient balance");
        assertEq(mERC20.balanceOf(trancheRecipients[1]), 0.5 ether, "3/invalid tranche 2 recipient balance - 1");

        assertEq(waterfallModuleERC20_OR.getPullBalance(trancheRecipients[0]), 0 ether, "4/invalid pull balance");
        assertEq(waterfallModuleERC20_OR.getPullBalance(trancheRecipients[1]), 0 ether, "5/invalid pull balance");

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 0.5 ether, "6/invalid distributed funds");
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 0 ether, "7/invalid funds pending withdrawal");

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 1 ether);
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 1 ether, "8/invalid waterfall balance");

        waterfallModuleERC20_OR.waterfallFundsPull();

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 1 ether, "9/invalid waterfall balance");
        assertEq(mERC20.balanceOf(trancheRecipients[0]), 0 ether, "10/invalid recipeint balance");
        assertEq(mERC20.balanceOf(trancheRecipients[1]), 0.5 ether, "11/invalid recipient balance");

        assertEq(waterfallModuleERC20_OR.getPullBalance(trancheRecipients[0]), 0, "12/invalid recipient pull balance");
        assertEq(waterfallModuleERC20_OR.getPullBalance(trancheRecipients[1]), 1 ether, "13/invalid recipient pull balance");

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 1.5 ether, "14/invalid distributed funds balance");
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 1 ether, "15/invalid funds pending balance");

        waterfallModuleERC20_OR.waterfallFundsPull();

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 1 ether, "16/invalid waterfall balance");
        assertEq(mERC20.balanceOf(trancheRecipients[0]), 0 ether, "17/invalid recipient balance");
        assertEq(mERC20.balanceOf(trancheRecipients[1]), 0.5 ether, "18/invalid recipient balance");

        assertEq(waterfallModuleERC20_OR.getPullBalance(trancheRecipients[0]), 0 ether, "19/invalid pull balance");
        assertEq(waterfallModuleERC20_OR.getPullBalance(trancheRecipients[1]), 1 ether, "20/invalid pull balance");

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 1.5 ether, "21/invalid distributed funds");
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 1 ether, "22/invalid funds pending");

        /// 3
        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 32 ether);
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 33 ether);

        waterfallModuleERC20_OR.waterfallFunds();

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 1 ether);
        assertEq(mERC20.balanceOf(trancheRecipients[0]), 32 ether);
        assertEq(mERC20.balanceOf(trancheRecipients[1]), 0.5 ether);

        assertEq(waterfallModuleERC20_OR.getPullBalance(trancheRecipients[0]), 0 ether);
        assertEq(waterfallModuleERC20_OR.getPullBalance(trancheRecipients[1]), 1 ether);

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 33.5 ether);
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 1 ether);

        waterfallModuleERC20_OR.withdraw(trancheRecipients[1]);

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0 ether);
        assertEq(mERC20.balanceOf(trancheRecipients[0]), 32 ether);
        assertEq(mERC20.balanceOf(trancheRecipients[1]), 1.5 ether);

        assertEq(waterfallModuleERC20_OR.getPullBalance(trancheRecipients[0]), 0 ether);
        assertEq(waterfallModuleERC20_OR.getPullBalance(trancheRecipients[1]), 0 ether);

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 33.5 ether);
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 0 ether);
    }

    function testFuzzCan_waterfallDepositsToRecipients(
        uint256 _recipientsSeed, 
        uint256 _thresholdsSeed, 
        uint8 _numDeposits, 
        uint256 _ethAmount, 
        uint256 _erc20Amount 
    ) public {
        _ethAmount = uint256(bound(_ethAmount, 0.01 ether, 34 ether));
        _erc20Amount = uint256(bound(_erc20Amount, 0.01 ether, 34 ether));
        vm.assume(_numDeposits > 0);
        (
            address[] memory _trancheRecipients,
            uint256 _trancheThreshold
        ) = generateTranches(_recipientsSeed, _thresholdsSeed);

        waterfallModuleETH = waterfallModuleFactory.createWaterfallModule(
            ETH_ADDRESS,
            nonWaterfallRecipient,
            _trancheRecipients,
            _trancheThreshold
        );

        waterfallModuleERC20 = waterfallModuleFactory.createWaterfallModule(
            address(mERC20),
            nonWaterfallRecipient,
            _trancheRecipients,
            _trancheThreshold
        );

        /// test eth
        for (uint256 i = 0; i < _numDeposits; i++) {
            address(waterfallModuleETH).safeTransferETH(_ethAmount);
        }
        waterfallModuleETH.waterfallFunds();


        uint256 _totalETHAmount = uint256(_numDeposits) * uint256(_ethAmount);

        assertEq(address(waterfallModuleETH).balance, 0 ether, "invalid balance");
        assertEq(waterfallModuleETH.distributedFunds(), _totalETHAmount, "undistributed funds");
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 0 ether, "funds pending withdraw");

        if (BALANCE_CLASSIFICATION_THRESHOLD > _totalETHAmount) {
            // then all of the deposit should be classified as reward
            assertEq(
                _trancheRecipients[0].balance,
                0,
                "should not classify reward as principal"
            );

            assertEq(
                _trancheRecipients[1].balance,
                _totalETHAmount,
                "invalid amount"
            );
        }

        if (_ethAmount > BALANCE_CLASSIFICATION_THRESHOLD) {
            // then all of reward classified as principal
            // but check if _totalETHAmount > first threshold
            if (_totalETHAmount > _trancheThreshold) {
                // there is reward
                assertEq(
                    _trancheRecipients[0].balance,
                    _trancheThreshold,
                    "invalid amount"
                );

                assertEq(
                    _trancheRecipients[1].balance,
                    _totalETHAmount - _trancheThreshold,
                    "should not classify principal as reward"
                );
            } else {
                // eelse no rewards
                assertEq(
                    _trancheRecipients[0].balance,
                    _totalETHAmount,
                    "invalid amount"
                );

                assertEq(
                    _trancheRecipients[1].balance,
                    0,
                    "should not classify principal as reward"
                );
            }
        }

        // test erc20

        for (uint256 i = 0; i < _numDeposits; i++) {
            address(mERC20).safeTransfer(address(waterfallModuleERC20), _erc20Amount);
            waterfallModuleERC20.waterfallFunds();
        }
        
        uint256 _totalERC20Amount = uint256(_numDeposits) * uint256(_erc20Amount);

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20)), 0 ether, "invalid erc20 balance");
        assertEq(waterfallModuleERC20.distributedFunds(), _totalERC20Amount, "incorrect distributed funds");
        assertEq(waterfallModuleERC20.fundsPendingWithdrawal(), 0 ether, "invalid funds pending withdrawal");
                
        if (BALANCE_CLASSIFICATION_THRESHOLD > _totalERC20Amount) {
            // then all of the deposit should be classified as reward
            assertEq(
                mERC20.balanceOf(_trancheRecipients[0]),
                0,
                "should not classify reward as principal"
            );

            assertEq(
                mERC20.balanceOf(_trancheRecipients[1]),
                _totalERC20Amount,
                "invalid amount reward classification"
            );
        }

        if (_erc20Amount > BALANCE_CLASSIFICATION_THRESHOLD) {
            // then all of reward classified as principal
            // but check if _totalERC20Amount > first threshold
            if (_totalERC20Amount > _trancheThreshold) {
                // there is reward
                assertEq(
                    mERC20.balanceOf(_trancheRecipients[0]),
                    _trancheThreshold,
                    "invalid amount principal classification"
                );

                assertEq(
                    mERC20.balanceOf(_trancheRecipients[1]),
                    _totalERC20Amount - _trancheThreshold,
                    "should not classify principal as reward"
                );
            } else {
                // eelse no rewards
                assertEq(
                    mERC20.balanceOf(_trancheRecipients[0]),
                    _totalERC20Amount,
                    "invalid amount"
                );

                assertEq(
                   mERC20.balanceOf(_trancheRecipients[1]),
                    0,
                    "should not classify principal as reward"
                );
            }
        }
    }

    function testFuzzCan_waterfallPullDepositsToRecipients(
        uint256 _recipientsSeed,
        uint256 _thresholdsSeed,
        uint8 _numDeposits,
        uint256 _ethAmount,
        uint256 _erc20Amount
    ) public {
        _ethAmount = uint256(bound(_ethAmount, 0.01 ether, 40 ether));
        _erc20Amount = uint256(bound(_erc20Amount, 0.01 ether, 40 ether));
        vm.assume(_numDeposits > 0);

        (
            address[] memory _trancheRecipients,
            uint256 _trancheThreshold
        ) = generateTranches(_recipientsSeed, _thresholdsSeed);

        waterfallModuleETH = waterfallModuleFactory.createWaterfallModule(
            ETH_ADDRESS,
            nonWaterfallRecipient,
            _trancheRecipients,
            _trancheThreshold
        );
        waterfallModuleERC20 = waterfallModuleFactory.createWaterfallModule(
            address(mERC20),
            nonWaterfallRecipient,
            _trancheRecipients,
            _trancheThreshold
        );

        /// test eth

        for (uint256 i = 0; i < _numDeposits; i++) {
            address(waterfallModuleETH).safeTransferETH(_ethAmount);
            waterfallModuleETH.waterfallFundsPull();
        }
        uint256 _totalETHAmount = uint256(_numDeposits) * uint256(_ethAmount);

        assertEq(address(waterfallModuleETH).balance, _totalETHAmount);
        assertEq(waterfallModuleETH.distributedFunds(), _totalETHAmount);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), _totalETHAmount);

        uint256 principal = waterfallModuleETH.getPullBalance(_trancheRecipients[0]);
        assertEq(
            waterfallModuleETH.getPullBalance(_trancheRecipients[0]),
            (_ethAmount >= BALANCE_CLASSIFICATION_THRESHOLD)
                ? _trancheThreshold > _totalETHAmount ? _totalETHAmount : _trancheThreshold
                : 0
            ,
            "5/invalid recipient balance"
        );

        uint256 reward = waterfallModuleETH.getPullBalance(_trancheRecipients[1]);
        assertEq(
            waterfallModuleETH.getPullBalance(_trancheRecipients[1]),
            (_ethAmount >= BALANCE_CLASSIFICATION_THRESHOLD)
                ? _totalETHAmount > _trancheThreshold ? (_totalETHAmount - _trancheThreshold) : 0
                : _totalETHAmount
            ,
            "6/invalid recipient balance"
        );

        
        waterfallModuleETH.withdraw(_trancheRecipients[0]);
        waterfallModuleETH.withdraw(_trancheRecipients[1]);


        assertEq(address(waterfallModuleETH).balance, 0);
        assertEq(waterfallModuleETH.distributedFunds(), _totalETHAmount);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 0);

        assertEq(_trancheRecipients[0].balance, principal, "10/invalid principal balance");
        assertEq(_trancheRecipients[1].balance, reward, "11/invalid reward balance");

        /// test erc20

        for (uint256 i = 0; i < _numDeposits; i++) {
            address(mERC20).safeTransfer(address(waterfallModuleERC20), _erc20Amount);
            waterfallModuleERC20.waterfallFundsPull();
        }
        uint256 _totalERC20Amount =
            uint256(_numDeposits) * uint256(_erc20Amount);

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20)), _totalERC20Amount);
        assertEq(waterfallModuleERC20.distributedFunds(), _totalERC20Amount);
        assertEq(waterfallModuleERC20.fundsPendingWithdrawal(), _totalERC20Amount);

        principal = waterfallModuleERC20.getPullBalance(_trancheRecipients[0]);
        assertEq(
            waterfallModuleERC20.getPullBalance(_trancheRecipients[0]),
            (_erc20Amount >= BALANCE_CLASSIFICATION_THRESHOLD)
                ? _trancheThreshold > _totalERC20Amount ? _totalERC20Amount : _trancheThreshold
                : 0
            ,
            "16/invalid recipient balance"
        );

        reward = waterfallModuleERC20.getPullBalance(_trancheRecipients[1]);
        assertEq(
            waterfallModuleERC20.getPullBalance(_trancheRecipients[1]),
            (_erc20Amount >= BALANCE_CLASSIFICATION_THRESHOLD)
                ? _totalERC20Amount > _trancheThreshold ? (_totalERC20Amount - _trancheThreshold) : 0
                : _totalERC20Amount
            ,
            "17/invalid recipient balance"
        );

        waterfallModuleERC20.withdraw(_trancheRecipients[0]);
        waterfallModuleERC20.withdraw(_trancheRecipients[1]);


        assertEq(mERC20.balanceOf(address(waterfallModuleERC20)), 0, "18/invalid balance");
        assertEq(waterfallModuleERC20.distributedFunds(), _totalERC20Amount, "19/invalid balance");
        assertEq(waterfallModuleERC20.fundsPendingWithdrawal(), 0, "20/invalid funds pending");

        assertEq(mERC20.balanceOf(_trancheRecipients[0]), principal, "21/invalid principal balance");
        assertEq(mERC20.balanceOf(_trancheRecipients[1]), reward, "22/invalid reward balance");
    }

}