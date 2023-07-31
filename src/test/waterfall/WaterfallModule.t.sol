// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import { WaterfallModule } from "src/waterfall/WaterfallModule.sol";
import { WaterfallModuleFactory } from "src/waterfall/WaterfallModuleFactory.sol";
import {MockERC20} from "../utils/mocks/MockERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract WaterfallModuleTest is Test {
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

    address internal constant ETH_ADDRESS = address(0);

    uint256 internal constant MAX_TRANCHE_SIZE = 2;
    uint256 internal constant BALANCE_CLASSIFICATION_THRESHOLD = 16 ether;
    uint256 internal constant ETH_STAKE = 32 ether;

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

        trancheRecipients = generateTrancheRecipients(2, uint256(uint160(makeAddr("tranche"))));
        // use 1 validator as default tranche threshold
        trancheThreshold = ETH_STAKE;

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

        waterfallModuleETH.recoverNonWaterfallFunds(address(mERC20), nonWaterfallRecipient);
        assertEq(address(waterfallModuleETH).balance, 1 ether);
        assertEq(mERC20.balanceOf(address(waterfallModuleETH)), 0 ether);
        assertEq(mERC20.balanceOf(nonWaterfallRecipient), 1 ether);

        waterfallModuleETH_OR.recoverNonWaterfallFunds(address(mERC20), address(0));
        assertEq(address(waterfallModuleETH_OR).balance, 1 ether);
        assertEq(mERC20.balanceOf(address(waterfallModuleETH_OR)), 0 ether);
        assertEq(mERC20.balanceOf(address(0)), 1 ether);

        address(mERC20).safeTransfer(address(waterfallModuleETH_OR), 1 ether);

        waterfallModuleETH_OR.recoverNonWaterfallFunds(address(mERC20), address(1));
        assertEq(address(waterfallModuleETH_OR).balance, 1 ether);
        assertEq(mERC20.balanceOf(address(waterfallModuleETH_OR)), 0 ether);
        assertEq(mERC20.balanceOf(address(1)), 1 ether);

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 1 ether);
        address(waterfallModuleERC20_OR).safeTransferETH(1 ether);
        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 1 ether);
        address(waterfallModuleERC20_OR).safeTransferETH(1 ether);

        waterfallModuleERC20_OR.recoverNonWaterfallFunds(ETH_ADDRESS, nonWaterfallRecipient);
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 1 ether);
        assertEq(address(waterfallModuleERC20_OR).balance, 0 ether);
        assertEq(nonWaterfallRecipient.balance, 1 ether);

        waterfallModuleERC20_OR.recoverNonWaterfallFunds(ETH_ADDRESS, address(0));
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 1 ether);
        assertEq(address(waterfallModuleERC20_OR).balance, 0 ether);
        assertEq(address(0).balance, 1 ether);

        address(waterfallModuleERC20_OR).safeTransferETH(1 ether);

        waterfallModuleERC20_OR.recoverNonWaterfallFunds(ETH_ADDRESS, address(1));
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 1 ether);
        assertEq(address(waterfallModuleERC20_OR).balance, 0 ether);
        assertEq(address(1).balance, 1 ether);
    }

    function testCan_emitOnRecoverNonWaterfallFundsToRecipient() public {
        address(waterfallModuleETH).safeTransferETH(1 ether);
        address(mERC20).safeTransfer(address(waterfallModuleETH), 1 ether);

        vm.expectEmit(true, true, true, true);
        emit RecoverNonWaterfallFunds(
            address(mERC20), nonWaterfallRecipient, 1 ether
            );
        waterfallModuleETH.recoverNonWaterfallFunds(address(mERC20), nonWaterfallRecipient);

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 1 ether);
        address(waterfallModuleERC20_OR).safeTransferETH(1 ether);

        vm.expectEmit(true, true, true, true);
        emit RecoverNonWaterfallFunds(
            ETH_ADDRESS, nonWaterfallRecipient, 1 ether
            );
        waterfallModuleERC20_OR.recoverNonWaterfallFunds(ETH_ADDRESS, nonWaterfallRecipient);

        address(waterfallModuleETH_OR).safeTransferETH(1 ether);
        address(mERC20).safeTransfer(address(waterfallModuleETH_OR), 1 ether);

        vm.expectEmit(true, true, true, true);
        emit RecoverNonWaterfallFunds(address(mERC20), address(1), 1 ether);
        waterfallModuleETH_OR.recoverNonWaterfallFunds(address(mERC20), address(1));

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 1 ether);
        address(waterfallModuleERC20_OR).safeTransferETH(1 ether);

        vm.expectEmit(true, true, true, true);
        emit RecoverNonWaterfallFunds(ETH_ADDRESS, address(1), 1 ether);
        waterfallModuleERC20_OR.recoverNonWaterfallFunds(ETH_ADDRESS, address(1));
    }

    function testCannot_recoverNonWaterfallFundsToNonRecipient() public {
        address(waterfallModuleETH).safeTransferETH(1 ether);
        address(mERC20).safeTransfer(address(waterfallModuleETH), 1 ether);

        vm.expectRevert(
            WaterfallModule.InvalidTokenRecovery_InvalidRecipient.selector
        );
        waterfallModuleETH.recoverNonWaterfallFunds(address(mERC20), address(1));

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 1 ether);
        address(waterfallModuleERC20_OR).safeTransferETH(1 ether);

        vm.expectRevert(
            WaterfallModule.InvalidTokenRecovery_InvalidRecipient.selector
        );
        waterfallModuleERC20_OR.recoverNonWaterfallFunds(ETH_ADDRESS, address(1));

        address(waterfallModuleETH_OR).safeTransferETH(1 ether);
        address(mERC20).safeTransfer(address(waterfallModuleETH_OR), 1 ether);

        vm.expectRevert(
            WaterfallModule.InvalidTokenRecovery_InvalidRecipient.selector
        );
        waterfallModuleETH_OR.recoverNonWaterfallFunds(address(mERC20), address(2));

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 1 ether);
        address(waterfallModuleERC20_OR).safeTransferETH(1 ether);

        vm.expectRevert(
            WaterfallModule.InvalidTokenRecovery_InvalidRecipient.selector
        );
        waterfallModuleERC20_OR.recoverNonWaterfallFunds(ETH_ADDRESS, address(2));
    }

    function testCannot_recoverWaterfallFunds() public {
        address(waterfallModuleETH).safeTransferETH(1 ether);
        address(mERC20).safeTransfer(address(waterfallModuleETH), 1 ether);

        vm.expectRevert(
            WaterfallModule.InvalidTokenRecovery_WaterfallToken.selector
        );
        waterfallModuleETH.recoverNonWaterfallFunds(ETH_ADDRESS, nonWaterfallRecipient);

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 1 ether);
        address(waterfallModuleERC20_OR).safeTransferETH(1 ether);

        vm.expectRevert(
            WaterfallModule.InvalidTokenRecovery_WaterfallToken.selector
        );
        waterfallModuleERC20_OR.recoverNonWaterfallFunds(address(mERC20), nonWaterfallRecipient);

        address(waterfallModuleETH_OR).safeTransferETH(1 ether);
        address(mERC20).safeTransfer(address(waterfallModuleETH_OR), 1 ether);

        vm.expectRevert(
            WaterfallModule.InvalidTokenRecovery_WaterfallToken.selector
        );
        waterfallModuleETH_OR.recoverNonWaterfallFunds(ETH_ADDRESS, address(1));

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 1 ether);
        address(waterfallModuleERC20_OR).safeTransferETH(1 ether);

        vm.expectRevert(
            WaterfallModule.InvalidTokenRecovery_WaterfallToken.selector
        );
        waterfallModuleERC20_OR.recoverNonWaterfallFunds(address(mERC20), address(1));
    }

    function testCan_waterfallIsPayable() public {
        waterfallModuleETH.waterfallFunds{value: 2 ether}();

        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(address(0).balance, 1 ether);
        assertEq(address(1).balance, 1 ether);
    }

    function testCan_waterfallToNoRecipients() public {
        waterfallModuleETH.waterfallFunds();
        assertEq(address(0).balance, 0 ether);

        waterfallModuleERC20_OR.waterfallFunds();
        assertEq(mERC20.balanceOf(address(0)), 0 ether);
    }

    function testCan_emitOnWaterfallToNoRecipients() public {
        vm.expectEmit(true, true, true, true);
        address[] memory recipients = new address[](1);
        recipients[0] = address(0);
        uint256[] memory payouts = new uint256[](1);
        payouts[0] = 0 ether;
        emit WaterfallFunds(recipients, payouts, 0);
        waterfallModuleETH.waterfallFunds();
    }

    function testCan_waterfallToFirstRecipient() public {
        address(waterfallModuleETH).safeTransferETH(1 ether);

        waterfallModuleETH.waterfallFunds();
        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(address(0).balance, 1 ether);

        waterfallModuleETH.waterfallFunds();
        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(address(0).balance, 1 ether);
        assertEq(address(1).balance, 0 ether);

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 1 ether);

        waterfallModuleERC20_OR.waterfallFunds();
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0 ether);
        assertEq(mERC20.balanceOf(address(0)), 1 ether);

        waterfallModuleERC20_OR.waterfallFunds();
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0 ether);
        assertEq(mERC20.balanceOf(address(0)), 1 ether);
        assertEq(mERC20.balanceOf(address(1)), 0 ether);
    }

    function testCan_emitOnWaterfallToFirstRecipient() public {
        address(waterfallModuleETH).safeTransferETH(1 ether);
        address[] memory recipients = new address[](1);
        recipients[0] = address(0);
        uint256[] memory payouts = new uint256[](1);
        payouts[0] = 1 ether;

        vm.expectEmit(true, true, true, true);
        emit WaterfallFunds(recipients, payouts, 0);
        waterfallModuleETH.waterfallFunds();

        address(waterfallModuleETH).safeTransferETH(1 ether);
        recipients[0] = address(1);

        vm.expectEmit(true, true, true, true);
        emit WaterfallFunds(recipients, payouts, 0);
        waterfallModuleETH.waterfallFunds();

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 1 ether);
        recipients[0] = address(0);

        vm.expectEmit(true, true, true, true);
        emit WaterfallFunds(recipients, payouts, 0);
        waterfallModuleERC20_OR.waterfallFunds();

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 1 ether);
        recipients[0] = address(1);

        vm.expectEmit(true, true, true, true);
        emit WaterfallFunds(recipients, payouts, 0);
        waterfallModuleERC20_OR.waterfallFunds();
    }

    function testCan_waterfallMultipleDepositsToFirstRecipient() public {
        address(waterfallModuleETH).safeTransferETH(0.5 ether);
        waterfallModuleETH.waterfallFunds();
        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(address(0).balance, 0.5 ether);

        address(waterfallModuleETH).safeTransferETH(0.5 ether);
        waterfallModuleETH.waterfallFunds();
        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(address(0).balance, 1 ether);

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 0.5 ether);
        waterfallModuleERC20_OR.waterfallFunds();
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0 ether);
        assertEq(mERC20.balanceOf(address(0)), 0.5 ether);

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 0.5 ether);
        waterfallModuleERC20_OR.waterfallFunds();
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0 ether);
        assertEq(mERC20.balanceOf(address(0)), 1 ether);
    }

    function testCan_waterfallToBothRecipients() public {
        address(waterfallModuleETH).safeTransferETH(2 ether);
        waterfallModuleETH.waterfallFunds();
        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(address(0).balance, 1 ether);
        assertEq(address(1).balance, 1 ether);

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 2 ether);
        waterfallModuleERC20_OR.waterfallFunds();
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0 ether);
        assertEq(mERC20.balanceOf(address(0)), 1 ether);
        assertEq(mERC20.balanceOf(address(1)), 1 ether);
    }

    function testCan_emitOnWaterfallToBothRecipients() public {
        address[] memory recipients = new address[](2);
        recipients[0] = address(0);
        recipients[1] = address(1);
        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 1 ether;
        payouts[1] = 1 ether;

        address(waterfallModuleETH).safeTransferETH(2 ether);
        vm.expectEmit(true, true, true, true);
        emit WaterfallFunds(recipients, payouts, 0);
        waterfallModuleETH.waterfallFunds();

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 2 ether);
        vm.expectEmit(true, true, true, true);
        emit WaterfallFunds(recipients, payouts, 0);
        waterfallModuleERC20_OR.waterfallFunds();
    }

    function testCan_waterfallMultipleDepositsToSecondRecipient() public {
        address(waterfallModuleETH).safeTransferETH(1 ether);
        waterfallModuleETH.waterfallFunds();

        address(waterfallModuleETH).safeTransferETH(1 ether);
        waterfallModuleETH.waterfallFunds();

        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(address(0).balance, 1 ether);
        assertEq(address(1).balance, 1 ether);

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 1 ether);
        waterfallModuleERC20_OR.waterfallFunds();

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 1 ether);
        waterfallModuleERC20_OR.waterfallFunds();

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0 ether);
        assertEq(mERC20.balanceOf(address(0)), 1 ether);
        assertEq(mERC20.balanceOf(address(1)), 1 ether);
    }

    function testCan_waterfallToResidualRecipient() public {
        address(waterfallModuleETH).safeTransferETH(10 ether);
        waterfallModuleETH.waterfallFunds();
        address(waterfallModuleETH).safeTransferETH(10 ether);
        waterfallModuleETH.waterfallFunds();

        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(address(0).balance, 1 ether);
        assertEq(address(1).balance, 19 ether);

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 10 ether);
        waterfallModuleERC20_OR.waterfallFunds();
        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 10 ether);
        waterfallModuleERC20_OR.waterfallFunds();

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0 ether);
        assertEq(mERC20.balanceOf(address(0)), 1 ether);
        assertEq(mERC20.balanceOf(address(1)), 19 ether);
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

    // function testCannot_reenterWaterfall() public {
    //     WaterfallReentrancy wr = new WaterfallReentrancy();

    //     uint256 _trancheRecipientsLength = 2;
    //     address[] memory _trancheRecipients =
    //         new address[](_trancheRecipientsLength);
    //     _trancheRecipients[0] = address(wr);
    //     _trancheRecipients[1] = address(0);
    //     uint256 _trancheThresholdsLength = _trancheRecipientsLength - 1;
    //     uint256[] memory _trancheThresholds =
    //         new uint256[](_trancheThresholdsLength);
    //     _trancheThresholds[0] = 1 ether;

    //     waterfallModuleETH = wmf.createWaterfallModule(
    //         ETH_ADDRESS,
    //         nonWaterfallRecipient,
    //         _trancheRecipients,
    //         _trancheThresholds
    //     );
    //     address(waterfallModuleETH).safeTransferETH(10 ether);
    //     vm.expectRevert(SafeTransferLib.ETHTransferFailed.selector);
    //     waterfallModuleETH.waterfallFunds();
    //     assertEq(address(waterfallModuleETH).balance, 10 ether);
    //     assertEq(address(wr).balance, 0 ether);
    //     assertEq(address(0).balance, 0 ether);
    // }

    function testCan_waterfallToPullFlow() public {
        // test eth
        address(waterfallModuleETH).safeTransferETH(10 ether);
        waterfallModuleETH.waterfallFundsPull();

        assertEq(address(waterfallModuleETH).balance, 10 ether);
        assertEq(address(0).balance, 0 ether);
        assertEq(address(1).balance, 0 ether);

        assertEq(waterfallModuleETH.getPullBalance(address(0)), 1 ether);
        assertEq(waterfallModuleETH.getPullBalance(address(1)), 9 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 10 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 10 ether);

        waterfallModuleETH.withdraw(address(0));

        assertEq(address(waterfallModuleETH).balance, 9 ether);
        assertEq(address(0).balance, 1 ether);
        assertEq(address(1).balance, 0 ether);

        assertEq(waterfallModuleETH.getPullBalance(address(0)), 0 ether);
        assertEq(waterfallModuleETH.getPullBalance(address(1)), 9 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 10 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 9 ether);

        waterfallModuleETH.withdraw(address(1));

        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(address(0).balance, 1 ether);
        assertEq(address(1).balance, 9 ether);

        assertEq(waterfallModuleETH.getPullBalance(address(0)), 0 ether);
        assertEq(waterfallModuleETH.getPullBalance(address(1)), 0 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 10 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 0 ether);

        // test erc20
        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 10 ether);
        waterfallModuleERC20_OR.waterfallFundsPull();

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 10 ether);
        assertEq(mERC20.balanceOf(address(0)), 0 ether);
        assertEq(mERC20.balanceOf(address(1)), 0 ether);

        assertEq(waterfallModuleERC20_OR.getPullBalance(address(0)), 1 ether);
        assertEq(waterfallModuleERC20_OR.getPullBalance(address(1)), 9 ether);

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 10 ether);
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 10 ether);

        waterfallModuleERC20_OR.withdraw(address(0));

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 9 ether);
        assertEq(mERC20.balanceOf(address(0)), 1 ether);
        assertEq(mERC20.balanceOf(address(1)), 0 ether);

        assertEq(waterfallModuleERC20_OR.getPullBalance(address(0)), 0 ether);
        assertEq(waterfallModuleERC20_OR.getPullBalance(address(1)), 9 ether);

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 10 ether);
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 9 ether);

        waterfallModuleERC20_OR.withdraw(address(1));

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0 ether);
        assertEq(mERC20.balanceOf(address(0)), 1 ether);
        assertEq(mERC20.balanceOf(address(1)), 9 ether);

        assertEq(waterfallModuleERC20_OR.getPullBalance(address(0)), 0 ether);
        assertEq(waterfallModuleERC20_OR.getPullBalance(address(1)), 0 ether);

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 10 ether);
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 0 ether);
    }

    function testCan_waterfallPushAndPull() public {
        // test eth
        address(waterfallModuleETH).safeTransferETH(0.5 ether);
        assertEq(address(waterfallModuleETH).balance, 0.5 ether);

        waterfallModuleETH.waterfallFunds();

        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(address(0).balance, 0.5 ether);
        assertEq(address(1).balance, 0 ether);

        assertEq(waterfallModuleETH.getPullBalance(address(0)), 0 ether);
        assertEq(waterfallModuleETH.getPullBalance(address(1)), 0 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 0.5 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 0 ether);

        address(waterfallModuleETH).safeTransferETH(1 ether);
        assertEq(address(waterfallModuleETH).balance, 1 ether);

        waterfallModuleETH.waterfallFundsPull();

        assertEq(address(waterfallModuleETH).balance, 1 ether);
        assertEq(address(0).balance, 0.5 ether);
        assertEq(address(1).balance, 0 ether);

        assertEq(waterfallModuleETH.getPullBalance(address(0)), 0.5 ether);
        assertEq(waterfallModuleETH.getPullBalance(address(1)), 0.5 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 1.5 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 1 ether);

        waterfallModuleETH.waterfallFunds();

        assertEq(address(waterfallModuleETH).balance, 1 ether);
        assertEq(address(0).balance, 0.5 ether);
        assertEq(address(1).balance, 0 ether);

        assertEq(waterfallModuleETH.getPullBalance(address(0)), 0.5 ether);
        assertEq(waterfallModuleETH.getPullBalance(address(1)), 0.5 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 1.5 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 1 ether);

        waterfallModuleETH.waterfallFundsPull();

        assertEq(address(waterfallModuleETH).balance, 1 ether);
        assertEq(address(0).balance, 0.5 ether);
        assertEq(address(1).balance, 0 ether);

        assertEq(waterfallModuleETH.getPullBalance(address(0)), 0.5 ether);
        assertEq(waterfallModuleETH.getPullBalance(address(1)), 0.5 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 1.5 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 1 ether);

        address(waterfallModuleETH).safeTransferETH(1 ether);
        assertEq(address(waterfallModuleETH).balance, 2 ether);

        waterfallModuleETH.waterfallFunds();

        assertEq(address(waterfallModuleETH).balance, 1 ether);
        assertEq(address(0).balance, 0.5 ether);
        assertEq(address(1).balance, 1 ether);

        assertEq(waterfallModuleETH.getPullBalance(address(0)), 0.5 ether);
        assertEq(waterfallModuleETH.getPullBalance(address(1)), 0.5 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 2.5 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 1 ether);

        waterfallModuleETH.withdraw(address(0));

        assertEq(address(waterfallModuleETH).balance, 0.5 ether);
        assertEq(address(0).balance, 1 ether);
        assertEq(address(1).balance, 1 ether);

        assertEq(waterfallModuleETH.getPullBalance(address(0)), 0 ether);
        assertEq(waterfallModuleETH.getPullBalance(address(1)), 0.5 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 2.5 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 0.5 ether);

        waterfallModuleETH.withdraw(address(1));

        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(address(0).balance, 1 ether);
        assertEq(address(1).balance, 1.5 ether);

        assertEq(waterfallModuleETH.getPullBalance(address(0)), 0 ether);
        assertEq(waterfallModuleETH.getPullBalance(address(1)), 0 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 2.5 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 0 ether);

        // test erc20
        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 0.5 ether);
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0.5 ether);

        waterfallModuleERC20_OR.waterfallFunds();

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0 ether);
        assertEq(mERC20.balanceOf(address(0)), 0.5 ether);
        assertEq(mERC20.balanceOf(address(1)), 0 ether);

        assertEq(waterfallModuleERC20_OR.getPullBalance(address(0)), 0 ether);
        assertEq(waterfallModuleERC20_OR.getPullBalance(address(1)), 0 ether);

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 0.5 ether);
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 0 ether);

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 1 ether);
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 1 ether);

        waterfallModuleERC20_OR.waterfallFundsPull();

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 1 ether);
        assertEq(mERC20.balanceOf(address(0)), 0.5 ether);
        assertEq(mERC20.balanceOf(address(1)), 0 ether);

        assertEq(waterfallModuleERC20_OR.getPullBalance(address(0)), 0.5 ether);
        assertEq(waterfallModuleERC20_OR.getPullBalance(address(1)), 0.5 ether);

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 1.5 ether);
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 1 ether);

        waterfallModuleERC20_OR.waterfallFundsPull();

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 1 ether);
        assertEq(mERC20.balanceOf(address(0)), 0.5 ether);
        assertEq(mERC20.balanceOf(address(1)), 0 ether);

        assertEq(waterfallModuleERC20_OR.getPullBalance(address(0)), 0.5 ether);
        assertEq(waterfallModuleERC20_OR.getPullBalance(address(1)), 0.5 ether);

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 1.5 ether);
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 1 ether);

        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 1 ether);
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 2 ether);

        waterfallModuleERC20_OR.waterfallFunds();

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 1 ether);
        assertEq(mERC20.balanceOf(address(0)), 0.5 ether);
        assertEq(mERC20.balanceOf(address(1)), 1 ether);

        assertEq(waterfallModuleERC20_OR.getPullBalance(address(0)), 0.5 ether);
        assertEq(waterfallModuleERC20_OR.getPullBalance(address(1)), 0.5 ether);

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 2.5 ether);
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 1 ether);

        waterfallModuleERC20_OR.withdraw(address(0));

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0.5 ether);
        assertEq(mERC20.balanceOf(address(0)), 1 ether);
        assertEq(mERC20.balanceOf(address(1)), 1 ether);

        assertEq(waterfallModuleERC20_OR.getPullBalance(address(0)), 0 ether);
        assertEq(waterfallModuleERC20_OR.getPullBalance(address(1)), 0.5 ether);

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 2.5 ether);
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 0.5 ether);

        waterfallModuleERC20_OR.withdraw(address(1));

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0 ether);
        assertEq(mERC20.balanceOf(address(0)), 1 ether);
        assertEq(mERC20.balanceOf(address(1)), 1.5 ether);

        assertEq(waterfallModuleERC20_OR.getPullBalance(address(0)), 0 ether);
        assertEq(waterfallModuleERC20_OR.getPullBalance(address(1)), 0 ether);

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 2.5 ether);
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 0 ether);
    }

    function testCan_waterfallPullNoMultiWithdraw() public {
        // test eth
        address(waterfallModuleETH).safeTransferETH(3 ether);
        assertEq(address(waterfallModuleETH).balance, 3 ether);

        waterfallModuleETH.waterfallFundsPull();

        assertEq(address(waterfallModuleETH).balance, 3 ether);
        assertEq(address(0).balance, 0 ether);
        assertEq(address(1).balance, 0 ether);

        assertEq(waterfallModuleETH.getPullBalance(address(0)), 1 ether);
        assertEq(waterfallModuleETH.getPullBalance(address(1)), 2 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 3 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 3 ether);

        waterfallModuleETH.withdraw(address(0));

        assertEq(address(waterfallModuleETH).balance, 2 ether);
        assertEq(address(0).balance, 1 ether);
        assertEq(address(1).balance, 0 ether);

        assertEq(waterfallModuleETH.getPullBalance(address(0)), 0 ether);
        assertEq(waterfallModuleETH.getPullBalance(address(1)), 2 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 3 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 2 ether);

        waterfallModuleETH.withdraw(address(0));

        assertEq(address(waterfallModuleETH).balance, 2 ether);
        assertEq(address(0).balance, 1 ether);
        assertEq(address(1).balance, 0 ether);

        assertEq(waterfallModuleETH.getPullBalance(address(0)), 0 ether);
        assertEq(waterfallModuleETH.getPullBalance(address(1)), 2 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 3 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 2 ether);

        waterfallModuleETH.withdraw(address(1));

        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(address(0).balance, 1 ether);
        assertEq(address(1).balance, 2 ether);

        assertEq(waterfallModuleETH.getPullBalance(address(0)), 0 ether);
        assertEq(waterfallModuleETH.getPullBalance(address(1)), 0 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 3 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 0 ether);

        waterfallModuleETH.withdraw(address(1));

        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(address(0).balance, 1 ether);
        assertEq(address(1).balance, 2 ether);

        assertEq(waterfallModuleETH.getPullBalance(address(0)), 0 ether);
        assertEq(waterfallModuleETH.getPullBalance(address(1)), 0 ether);

        assertEq(waterfallModuleETH.distributedFunds(), 3 ether);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 0 ether);

        // test erc20
        address(mERC20).safeTransfer(address(waterfallModuleERC20_OR), 3 ether);
        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 3 ether);

        waterfallModuleERC20_OR.waterfallFundsPull();

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 3 ether);
        assertEq(mERC20.balanceOf(address(0)), 0 ether);
        assertEq(mERC20.balanceOf(address(1)), 0 ether);

        assertEq(waterfallModuleERC20_OR.getPullBalance(address(0)), 1 ether);
        assertEq(waterfallModuleERC20_OR.getPullBalance(address(1)), 2 ether);

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 3 ether);
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 3 ether);

        waterfallModuleERC20_OR.withdraw(address(0));

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 2 ether);
        assertEq(mERC20.balanceOf(address(0)), 1 ether);
        assertEq(mERC20.balanceOf(address(1)), 0 ether);

        assertEq(waterfallModuleERC20_OR.getPullBalance(address(0)), 0 ether);
        assertEq(waterfallModuleERC20_OR.getPullBalance(address(1)), 2 ether);

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 3 ether);
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 2 ether);

        waterfallModuleERC20_OR.withdraw(address(0));

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 2 ether);
        assertEq(mERC20.balanceOf(address(0)), 1 ether);
        assertEq(mERC20.balanceOf(address(1)), 0 ether);

        assertEq(waterfallModuleERC20_OR.getPullBalance(address(0)), 0 ether);
        assertEq(waterfallModuleERC20_OR.getPullBalance(address(1)), 2 ether);

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 3 ether);
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 2 ether);

        waterfallModuleERC20_OR.withdraw(address(1));

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0 ether);
        assertEq(mERC20.balanceOf(address(0)), 1 ether);
        assertEq(mERC20.balanceOf(address(1)), 2 ether);

        assertEq(waterfallModuleERC20_OR.getPullBalance(address(0)), 0 ether);
        assertEq(waterfallModuleERC20_OR.getPullBalance(address(1)), 0 ether);

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 3 ether);
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 0 ether);

        waterfallModuleERC20_OR.withdraw(address(1));

        assertEq(mERC20.balanceOf(address(waterfallModuleERC20_OR)), 0 ether);
        assertEq(mERC20.balanceOf(address(0)), 1 ether);
        assertEq(mERC20.balanceOf(address(1)), 2 ether);

        assertEq(waterfallModuleERC20_OR.getPullBalance(address(0)), 0 ether);
        assertEq(waterfallModuleERC20_OR.getPullBalance(address(1)), 0 ether);

        assertEq(waterfallModuleERC20_OR.distributedFunds(), 3 ether);
        assertEq(waterfallModuleERC20_OR.fundsPendingWithdrawal(), 0 ether);
    }





    // function test_fuzz_waterfallDepositsToRecipients(
    //     uint256 _recipientsSeed, 
    //     uint256 _thresholdsSeed, 
    //     uint8 _numDeposits, 
    //     uint256 _ethAmount, 
    //     uint96 _erc20Amount 
    // ) public {
    //     _ethAmount = uint256(bound(_ethAmount, 0.01 ether, 34 ether));
    //     console.logString("eth amount");
    //     console.log(_ethAmount);

    //     (
    //         address[] memory _trancheRecipients,
    //         uint256[] memory _trancheThresholds
    //     ) = generateTranches(_recipientsSeed, _thresholdsSeed);

    //     waterfallModuleETH = waterfallModuleFactory.createWaterfallModule(
    //         ETH_ADDRESS,
    //         nonWaterfallRecipient,
    //         _trancheRecipients,
    //         _trancheThresholds
    //     );

    //     waterfallModuleERC20 = waterfallModuleFactory.createWaterfallModule(
    //         address(mERC20),
    //         nonWaterfallRecipient,
    //         _trancheRecipients,
    //         _trancheThresholds
    //     );

    //     /// test eth
    //     for (uint256 i = 0; i < _numDeposits; i++) {
    //         address(waterfallModuleETH).safeTransferETH(_ethAmount);
    //     }
    //     waterfallModuleETH.waterfallFunds();


    //     uint256 _totalETHAmount = uint256(_numDeposits) * uint256(_ethAmount);

    //     assertEq(address(waterfallModuleETH).balance, 0 ether, "invalid balance");
    //     assertEq(waterfallModuleETH.distributedFunds(), _totalETHAmount, "undistributed funds");
    //     assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 0 ether, "funds pending withdraw");

    //     if (BALANCE_CLASSIFICATION_THRESHOLD > _totalETHAmount) {
    //         // then all of the deposit should be classified as reward
    //         assertEq(
    //             _trancheRecipients[0].balance,
    //             0,
    //             "should not classify reward as principal"
    //         );

    //         assertEq(
    //             _trancheRecipients[1].balance,
    //             _totalETHAmount,
    //             "invalid amount"
    //         );
    //     }

    //     if (_ethAmount > BALANCE_CLASSIFICATION_THRESHOLD) {
    //         // then all of reward classified as principal
    //         // but check if _totalETHAmount > first threshold
    //         if (_totalETHAmount > _trancheThresholds[0]) {
    //             // there is reward
    //             assertEq(
    //                 _trancheRecipients[0].balance,
    //                 _trancheThresholds[0],
    //                 "invalid amount"
    //             );

    //             assertEq(
    //                 _trancheRecipients[1].balance,
    //                 _totalETHAmount - _trancheThresholds[0],
    //                 "should not classify principal as reward"
    //             );
    //         } else {
    //             // eelse no rewards
    //             assertEq(
    //                 _trancheRecipients[0].balance,
    //                 _totalETHAmount,
    //                 "invalid amount"
    //             );

    //             assertEq(
    //                 _trancheRecipients[1].balance,
    //                 0,
    //                 "should not classify principal as reward"
    //             );
    //         }
    //     }

        /// test erc20

        // for (uint256 i = 0; i < _numDeposits; i++) {
        //     address(mERC20).safeTransfer(address(waterfallModuleERC20), _erc20Amount);
        //     waterfallModuleERC20.waterfallFunds();
        // }
        
        // uint256 _totalERC20Amount = uint256(_numDeposits) * uint256(_erc20Amount);

        // assertEq(mERC20.balanceOf(address(waterfallModuleERC20)), 0 ether, "invalid erc20 balance");
        // assertEq(waterfallModuleERC20.distributedFunds(), _totalERC20Amount, "incorrect distributed funds");
        // assertEq(waterfallModuleERC20.fundsPendingWithdrawal(), 0 ether, "invalid funds pending withdrawal");

        // assertEq(
        //     mERC20.balanceOf(_trancheRecipients[0]),
        //     (_totalERC20Amount >= _trancheThresholds[0])
        //         ? _trancheThresholds[0]
        //         : _totalERC20Amount
        // );
        // for (uint256 i = 1; i < _trancheThresholds.length; i++) {
        //     if (_totalERC20Amount >= _trancheThresholds[i]) {
        //         assertEq(
        //             mERC20.balanceOf(_trancheRecipients[i]),
        //             _trancheThresholds[i] - _trancheThresholds[i - 1]
        //         );
        //     } else if (_totalERC20Amount > _trancheThresholds[i - 1]) {
        //         assertEq(
        //             mERC20.balanceOf(_trancheRecipients[i]),
        //             _totalERC20Amount - _trancheThresholds[i - 1]
        //         );
        //     } else {
        //         assertEq(mERC20.balanceOf(_trancheRecipients[i]), 0);
        //     }
        // }
        // assertEq(
        //     mERC20.balanceOf(_trancheRecipients[_trancheRecipients.length - 1]),
        //     (
        //         _totalERC20Amount
        //             > _trancheThresholds[_trancheRecipients.length - 2]
        //     )
        //         ? _totalERC20Amount
        //             - _trancheThresholds[_trancheRecipients.length - 2]
        //         : 0
        // );
    // }

    /// -----------------------------------------------------------------------
    /// helper fns
    /// -----------------------------------------------------------------------

    function generateTranches(uint256 rSeed, uint256 tSeed)
        internal
        pure
        returns (address[] memory recipients, uint256 threshold)
    {
        recipients = generateTrancheRecipients(MAX_TRANCHE_SIZE, rSeed);
        threshold = generateTrancheThreshold(tSeed);
    }

    function generateTrancheRecipients(uint256 numRecipients, uint256 _seed)
        internal
        pure
        returns (address[] memory recipients)
    {
        recipients = new address[](numRecipients);
        bytes32 seed = bytes32(_seed);
        for (uint256 i = 0; i < numRecipients; i++) {
            seed = keccak256(abi.encodePacked(seed));
            recipients[i] = address(bytes20(seed));
        }
    }

    function generateTrancheThreshold(uint256 _seed)
        internal
        pure
        returns (uint256 threshold)
    {
        uint256 seed = _seed;
        seed = uint256(keccak256(abi.encodePacked(seed)));
        threshold = uint96(seed);
    }
}