// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import { OptimisticWithdrawalRecipient } from "src/waterfall/OptimisticWithdrawalRecipient.sol";
import { OptimisticWithdrawalRecipientFactory } from "src/waterfall/OptimisticWithdrawalRecipientFactory.sol";
import {MockERC20} from "../utils/mocks/MockERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {OWRTestHelper} from "./OWRTestHelper.t.sol";

contract OptimisticWithdrawalRecipientTest is OWRTestHelper, Test {
    using SafeTransferLib for address;

    event ReceiveETH(uint256 amount);

    event DistributeFunds(
        address[] recipients, uint256[] payouts, uint256 pullFlowFlag
    );

    event RecoverNonWaterfallFunds(
        address nonWaterfallToken, address recipient, uint256 amount
    );

    OptimisticWithdrawalRecipient public owrModule;
    OptimisticWithdrawalRecipientFactory public owrFactory;
    address public nonWaterfallRecipient;

    OptimisticWithdrawalRecipient owrETH;
    OptimisticWithdrawalRecipient owrERC20;
    OptimisticWithdrawalRecipient owrETH_OR;
    OptimisticWithdrawalRecipient owrERC20_OR;
    MockERC20 mERC20;

    address public principalRecipient;
    address public rewardRecipient;
    uint256 internal trancheThreshold;

    function setUp() public {
        owrFactory = new OptimisticWithdrawalRecipientFactory();
        owrModule = owrFactory.owrImpl();

        mERC20 = new MockERC20("demo", "DMT", 18);
        mERC20.mint(type(uint256).max);

        (principalRecipient, rewardRecipient) = generateTrancheRecipients(uint256(uint160(makeAddr("tranche"))));
        // use 1 validator as default tranche threshold
        trancheThreshold = ETH_STAKE;

        nonWaterfallRecipient = makeAddr("nonWaterfallRecipient");

        owrETH = owrFactory.createOWRecipient(
            ETH_ADDRESS,
            nonWaterfallRecipient,
            principalRecipient, rewardRecipient,
            trancheThreshold
        );

        owrERC20 = owrFactory.createOWRecipient(
            address(mERC20),
            nonWaterfallRecipient,
            principalRecipient, rewardRecipient,
            trancheThreshold
        );

        owrETH_OR = owrFactory.createOWRecipient(
            ETH_ADDRESS, address(0), principalRecipient, rewardRecipient, trancheThreshold
        );
        owrERC20_OR = owrFactory.createOWRecipient(
            address(mERC20), address(0), principalRecipient, rewardRecipient, trancheThreshold
        );
    }

    function testGetTranches() public {
        // eth
        (address[] memory recipients, uint256 wtrancheThreshold)
        = owrETH.getTranches();

        assertEq(recipients[0], principalRecipient, "invalid principal recipient");
        assertEq(recipients[1], rewardRecipient, "invalid reward recipient");
        assertEq(wtrancheThreshold, ETH_STAKE, "invalid eth tranche threshold");
        
        // erc20
        (recipients, wtrancheThreshold) = owrERC20.getTranches();
        
        assertEq(recipients[0], principalRecipient, "invalid erc20 principal recipient");
        assertEq(recipients[1], rewardRecipient, "invalid erc20 reward recipient");        
        assertEq(wtrancheThreshold, ETH_STAKE, "invalid erc20 tranche threshold");
    }

    function testReceiveETH() public {
        address(owrETH).safeTransferETH(1 ether);
        assertEq(address(owrETH).balance, 1 ether);

        address(owrERC20).safeTransferETH(1 ether);
        assertEq(address(owrERC20).balance, 1 ether);
    }

    function testReceiveTransfer() public {
        payable(address(owrETH)).transfer(1 ether);
        assertEq(address(owrETH).balance, 1 ether);

        payable(address(owrERC20)).transfer(1 ether);
        assertEq(address(owrERC20).balance, 1 ether);
    }

    function testEmitOnReceiveETH() public {
        vm.expectEmit(true, true, true, true);
        emit ReceiveETH(1 ether);

        address(owrETH).safeTransferETH(1 ether);
    }

    function testReceiveERC20() public {       
        address(mERC20).safeTransfer(address(owrETH), 1 ether);
        assertEq(mERC20.balanceOf(address(owrETH)), 1 ether);

        address(mERC20).safeTransfer(address(owrERC20), 1 ether);
        assertEq(mERC20.balanceOf(address(owrERC20)), 1 ether);
    }

    // function testCan_recoverNonWaterfallFundsToRecipient() public {
    //     address(owrETH).safeTransferETH(1 ether);
    //     address(mERC20).safeTransfer(address(owrETH), 1 ether);
    //     address(owrETH_OR).safeTransferETH(1 ether);
    //     address(mERC20).safeTransfer(address(owrETH_OR), 1 ether);

    //     vm.expectEmit(true, true, true, true);
    //     emit RecoverNonWaterfallFunds(
    //         address(mERC20), nonWaterfallRecipient, 1 ether
    //     );
    //     owrETH.recoverNonWaterfallFunds(address(mERC20), nonWaterfallRecipient);
    //     assertEq(address(owrETH).balance, 1 ether);
    //     assertEq(mERC20.balanceOf(address(owrETH)), 0 ether);
    //     assertEq(mERC20.balanceOf(nonWaterfallRecipient), 1 ether);

    //     vm.expectEmit(true, true, true, true);
    //     emit RecoverNonWaterfallFunds(
    //         address(mERC20), trancheRecipients[0], 1 ether
    //     );
    //     owrETH_OR.recoverNonWaterfallFunds(address(mERC20), trancheRecipients[0]);
    //     assertEq(address(owrETH_OR).balance, 1 ether);
    //     assertEq(mERC20.balanceOf(address(owrETH_OR)), 0 ether);
    //     assertEq(mERC20.balanceOf(trancheRecipients[0]), 1 ether);

    //     address(mERC20).safeTransfer(address(owrETH_OR), 1 ether);

    //     vm.expectEmit(true, true, true, true);
    //     emit RecoverNonWaterfallFunds(
    //         address(mERC20), trancheRecipients[1], 1 ether
    //     );
    //     owrETH_OR.recoverNonWaterfallFunds(address(mERC20), trancheRecipients[1]);
    //     assertEq(address(owrETH_OR).balance, 1 ether);
    //     assertEq(mERC20.balanceOf(address(owrETH_OR)), 0 ether);
    //     assertEq(mERC20.balanceOf(trancheRecipients[1]), 1 ether);
        
 
    //     address(owrERC20).safeTransferETH(1 ether);
    //     address(mERC20).safeTransfer(address(owrERC20), 1 ether);

        
    //     vm.expectEmit(true, true, true, true);
    //     emit RecoverNonWaterfallFunds(
    //         ETH_ADDRESS, nonWaterfallRecipient, 1 ether
    //     );
    //     owrERC20.recoverNonWaterfallFunds(ETH_ADDRESS, nonWaterfallRecipient);
    //     assertEq(mERC20.balanceOf(address(owrERC20)), 1 ether);
    //     assertEq(address(owrERC20).balance, 0 ether);
    //     assertEq(nonWaterfallRecipient.balance, 1 ether);


    //     address(owrERC20_OR).safeTransferETH(1 ether);
    //     address(mERC20).safeTransfer(address(owrERC20_OR), 1 ether);

    //     vm.expectEmit(true, true, true, true);
    //     emit RecoverNonWaterfallFunds(
    //         ETH_ADDRESS, trancheRecipients[0], 1 ether
    //     );
    //     owrERC20_OR.recoverNonWaterfallFunds(ETH_ADDRESS, trancheRecipients[0]);
    //     assertEq(mERC20.balanceOf(address(owrERC20_OR)), 1 ether);
    //     assertEq(address(owrERC20_OR).balance, 0 ether);
    //     assertEq(trancheRecipients[0].balance, 1 ether);

    //     address(owrERC20_OR).safeTransferETH(1 ether);

    //     owrERC20_OR.recoverNonWaterfallFunds(ETH_ADDRESS, trancheRecipients[1]);
    //     assertEq(mERC20.balanceOf(address(owrERC20_OR)), 1 ether);
    //     assertEq(address(owrERC20_OR).balance, 0 ether, "invalid erc20 balance");
    //     assertEq(trancheRecipients[1].balance, 1 ether, "invalid eth balance");
    // }

    // function testCannot_recoverNonWaterfallFundsToNonRecipient() public {
    //     vm.expectRevert(
    //         WaterfallModule.InvalidTokenRecovery_InvalidRecipient.selector
    //     );
    //     owrETH.recoverNonWaterfallFunds(address(mERC20), address(1));

    //     vm.expectRevert(
    //         WaterfallModule.InvalidTokenRecovery_InvalidRecipient.selector
    //     );
    //     owrERC20_OR.recoverNonWaterfallFunds(ETH_ADDRESS, address(1));

    //     vm.expectRevert(
    //         WaterfallModule.InvalidTokenRecovery_InvalidRecipient.selector
    //     );
    //     owrETH_OR.recoverNonWaterfallFunds(address(mERC20), address(2));

    //     vm.expectRevert(
    //         WaterfallModule.InvalidTokenRecovery_InvalidRecipient.selector
    //     );
    //     owrERC20_OR.recoverNonWaterfallFunds(ETH_ADDRESS, address(2));
    // }

    // function testCannot_recoverWaterfallFunds() public {
    //     vm.expectRevert(
    //         WaterfallModule.InvalidTokenRecovery_WaterfallToken.selector
    //     );
    //     owrETH.recoverNonWaterfallFunds(ETH_ADDRESS, nonWaterfallRecipient);

    //     vm.expectRevert(
    //         WaterfallModule.InvalidTokenRecovery_WaterfallToken.selector
    //     );
    //     owrERC20_OR.recoverNonWaterfallFunds(address(mERC20), nonWaterfallRecipient);

    //     vm.expectRevert(
    //         WaterfallModule.InvalidTokenRecovery_WaterfallToken.selector
    //     );
    //     owrETH_OR.recoverNonWaterfallFunds(ETH_ADDRESS, address(1));

    //     vm.expectRevert(
    //         WaterfallModule.InvalidTokenRecovery_WaterfallToken.selector
    //     );
    //     owrERC20_OR.recoverNonWaterfallFunds(address(mERC20), address(1));
    // }

    // function testCan_waterfallIsPayable() public {
    //     owrETH.waterfallFunds{value: 2 ether}();

    //     assertEq(address(owrETH).balance, 0 ether);
    //     assertEq(trancheRecipients[0].balance, 0);
    //     assertEq(trancheRecipients[1].balance, 2 ether);
    // }

    // function testCan_waterfallToNoRecipients() public {
    //     owrETH.waterfallFunds();
    //     assertEq(trancheRecipients[0].balance, 0 ether);

    //     owrERC20_OR.waterfallFunds();
    //     assertEq(mERC20.balanceOf(trancheRecipients[0]), 0 ether);
    // }

    // function testCan_emitOnWaterfallToNoRecipients() public {
    //     uint256[] memory payouts = new uint256[](2);
    //     payouts[0] = 0 ether;
    //     payouts[1] = 0 ether;

    //     vm.expectEmit(true, true, true, true);
    //     emit WaterfallFunds(principalRecipient, rewardRecipient, payouts, 0);
    //     owrETH.waterfallFunds();
    // }

    // function testCan_waterfallToSecondRecipient() public {
    //     address(owrETH).safeTransferETH(1 ether);
        
    //     uint256[] memory payouts = new uint256[](2);
    //     payouts[1] = 1 ether;

    //     vm.expectEmit(true, true, true, true);
    //     emit WaterfallFunds(principalRecipient, rewardRecipient, payouts, 0);
    //     owrETH.waterfallFunds();
    //     assertEq(address(owrETH).balance, 0 ether);
    //     assertEq(trancheRecipients[1].balance, 1 ether);

    //     payouts[1] = 0;    
    //     vm.expectEmit(true, true, true, true);
    //     emit WaterfallFunds(principalRecipient, rewardRecipient, payouts, 0);
    //     owrETH.waterfallFunds();
    //     assertEq(address(owrETH).balance, 0 ether);
    //     assertEq(trancheRecipients[0].balance, 0 ether);
    //     assertEq(trancheRecipients[1].balance, 1 ether);

    //     address(mERC20).safeTransfer(address(owrERC20_OR), 1 ether);

    //     payouts[1] = 1 ether;    
    //     vm.expectEmit(true, true, true, true);
    //     emit WaterfallFunds(principalRecipient, rewardRecipient, payouts, 0);
    //     owrERC20_OR.waterfallFunds();
    //     assertEq(mERC20.balanceOf(address(owrERC20_OR)), 0 ether);
    //     assertEq(mERC20.balanceOf(trancheRecipients[1]), 1 ether);

    //     payouts[1] = 0;    
    //     vm.expectEmit(true, true, true, true);
    //     emit WaterfallFunds(principalRecipient, rewardRecipient, payouts, 0);
    //     owrERC20_OR.waterfallFunds();
    //     assertEq(mERC20.balanceOf(address(owrERC20_OR)), 0 ether);
    //     assertEq(trancheRecipients[0].balance, 0 ether);
    //     assertEq(trancheRecipients[1].balance, 1 ether);
    // }

    // function testCan_waterfallMultipleDepositsToRewardRecipient() public {
    //     address(owrETH).safeTransferETH(0.5 ether);
    //     owrETH.waterfallFunds();
    //     assertEq(address(owrETH).balance, 0 ether);
    //     assertEq(trancheRecipients[1].balance, 0.5 ether);

    //     address(owrETH).safeTransferETH(0.5 ether);
    //     owrETH.waterfallFunds();
    //     assertEq(address(owrETH).balance, 0 ether);
    //     assertEq(trancheRecipients[1].balance, 1 ether);

    //     address(mERC20).safeTransfer(address(owrERC20_OR), 0.5 ether);
    //     owrERC20_OR.waterfallFunds();
    //     assertEq(mERC20.balanceOf(address(owrERC20_OR)), 0 ether);
    //     assertEq(mERC20.balanceOf(trancheRecipients[1]), 0.5 ether);

    //     address(mERC20).safeTransfer(address(owrERC20_OR), 0.5 ether);
    //     owrERC20_OR.waterfallFunds();
    //     assertEq(mERC20.balanceOf(address(owrERC20_OR)), 0 ether);
    //     assertEq(mERC20.balanceOf(trancheRecipients[1]), 1 ether);
    // }

    // function testCan_waterfallToBothRecipients() public {
    //     address(owrETH).safeTransferETH(36 ether);

    //     uint256[] memory payouts = new uint256[](2);
    //     payouts[0] = 32 ether;
    //     payouts[1] = 4 ether;

    //     vm.expectEmit(true, true, true, true);
    //     emit WaterfallFunds(principalRecipient, rewardRecipient, payouts, 0);
    //     owrETH.waterfallFunds();
    //     assertEq(address(owrETH).balance, 0 ether);
    //     assertEq(trancheRecipients[0].balance, 32 ether);
    //     assertEq(trancheRecipients[1].balance, 4 ether);

    //     address(mERC20).safeTransfer(address(owrERC20_OR), 36 ether);
        
    //     vm.expectEmit(true, true, true, true);
    //     emit WaterfallFunds(principalRecipient, rewardRecipient, payouts, 0);
    //     owrERC20_OR.waterfallFunds();
    //     assertEq(mERC20.balanceOf(address(owrERC20_OR)), 0 ether);
    //     assertEq(trancheRecipients[0].balance, 32 ether);
    //     assertEq(trancheRecipients[1].balance, 4 ether);
    // }

    // function testCan_waterfallMultipleDepositsToPrincipalRecipient() public {
    //     address(owrETH).safeTransferETH(16 ether);
    //     owrETH.waterfallFunds();

    //     address(owrETH).safeTransferETH(16 ether);
    //     owrETH.waterfallFunds();

    //     assertEq(address(owrETH).balance, 0 ether);
    //     assertEq(trancheRecipients[0].balance, 32 ether);
    //     assertEq(trancheRecipients[1].balance, 0 ether);

    //     address(mERC20).safeTransfer(address(owrERC20_OR), 16 ether);
    //     owrERC20_OR.waterfallFunds();

    //     address(mERC20).safeTransfer(address(owrERC20_OR), 16 ether);
    //     owrERC20_OR.waterfallFunds();

    //     assertEq(mERC20.balanceOf(address(owrERC20_OR)), 0 ether);
    //     assertEq(mERC20.balanceOf(trancheRecipients[0]), 32 ether);
    //     assertEq(mERC20.balanceOf(trancheRecipients[1]), 0);
    // }

    // function testCannot_distributeTooMuch() public {
    //     vm.deal(address(owrETH), type(uint128).max);
    //     owrETH.waterfallFunds();
    //     vm.deal(address(owrETH), 1);

    //     vm.expectRevert(WaterfallModule.InvalidDistribution_TooLarge.selector);
    //     owrETH.waterfallFunds();

    //     vm.expectRevert(WaterfallModule.InvalidDistribution_TooLarge.selector);
    //     owrETH.waterfallFundsPull();

    //     address(mERC20).safeTransfer(address(owrERC20_OR), type(uint128).max);
    //     owrERC20_OR.waterfallFunds();
    //     address(mERC20).safeTransfer(address(owrERC20_OR), 1);

    //     vm.expectRevert(WaterfallModule.InvalidDistribution_TooLarge.selector);
    //     owrERC20_OR.waterfallFunds();

    //     vm.expectRevert(WaterfallModule.InvalidDistribution_TooLarge.selector);
    //     owrERC20_OR.waterfallFundsPull();
    // }

    // // // function testCannot_reenterWaterfall() public {
    // // //     WaterfallReentrancy wr = new WaterfallReentrancy();

    // // //     uint256 _trancheRecipientsLength = 2;
    // // //     address[] memory _trancheRecipients =
    // // //         new address[](_trancheRecipientsLength);
    // // //     _trancheRecipients[0] = address(wr);
    // // //     _trancheRecipients[1] = address(0);
    // // //     uint256 _trancheThresholdsLength = _trancheRecipientsLength - 1;
    // // //     uint256[] memory _trancheThresholds =
    // // //         new uint256[](_trancheThresholdsLength);
    // // //     _trancheThresholds[0] = 1 ether;

    // // //     owrETH = wmf.createOWRecipient(
    // // //         ETH_ADDRESS,
    // // //         nonWaterfallRecipient,
    // // //         _principalRecipient, rewardRecipient,
    // // //         _trancheThresholds
    // // //     );
    // // //     address(owrETH).safeTransferETH(10 ether);
    // // //     vm.expectRevert(SafeTransferLib.ETHTransferFailed.selector);
    // // //     owrETH.waterfallFunds();
    // // //     assertEq(address(owrETH).balance, 10 ether);
    // // //     assertEq(address(wr).balance, 0 ether);
    // // //     assertEq(address(0).balance, 0 ether);
    // // // }

    // function testCan_waterfallToPullFlow() public {
    //     // test eth
    //     address(owrETH).safeTransferETH(36 ether);
    //     owrETH.waterfallFundsPull();

    //     assertEq(address(owrETH).balance, 36 ether);
    //     assertEq(trancheRecipients[0].balance, 0 ether);
    //     assertEq(trancheRecipients[1].balance, 0 ether);

    //     assertEq(owrETH.getPullBalance(trancheRecipients[0]), 32 ether);
    //     assertEq(owrETH.getPullBalance(trancheRecipients[1]), 4 ether);

    //     assertEq(owrETH.distributedFunds(), 36 ether);
    //     assertEq(owrETH.fundsPendingWithdrawal(), 36 ether);

    //     owrETH.withdraw(trancheRecipients[1]);

    //     assertEq(address(owrETH).balance, 32 ether);
    //     assertEq(trancheRecipients[0].balance, 0);
    //     assertEq(trancheRecipients[1].balance, 4 ether);

    //     assertEq(owrETH.getPullBalance(trancheRecipients[0]), 32 ether);
    //     assertEq(owrETH.getPullBalance(trancheRecipients[1]), 0);

    //     assertEq(owrETH.distributedFunds(), 36 ether);
    //     assertEq(owrETH.fundsPendingWithdrawal(), 32 ether);

    //     owrETH.withdraw(trancheRecipients[0]);

    //     assertEq(address(owrETH).balance, 0 ether);
    //     assertEq(trancheRecipients[0].balance, 32 ether);
    //     assertEq(trancheRecipients[1].balance, 4 ether);

    //     assertEq(owrETH.getPullBalance(trancheRecipients[0]), 0);
    //     assertEq(owrETH.getPullBalance(trancheRecipients[1]), 0);

    //     assertEq(owrETH.distributedFunds(), 36 ether);
    //     assertEq(owrETH.fundsPendingWithdrawal(), 0 ether);

    //     // test erc20
    //     address(mERC20).safeTransfer(address(owrERC20_OR), 36 ether);
    //     owrERC20_OR.waterfallFundsPull();

    //     assertEq(mERC20.balanceOf(address(owrERC20_OR)), 36 ether);
    //     assertEq(mERC20.balanceOf(trancheRecipients[0]), 0);
    //     assertEq(mERC20.balanceOf(trancheRecipients[1]), 0);

    //     assertEq(owrERC20_OR.getPullBalance(trancheRecipients[0]), 32 ether);
    //     assertEq(owrERC20_OR.getPullBalance(trancheRecipients[1]), 4 ether);

    //     assertEq(owrERC20_OR.distributedFunds(), 36 ether);
    //     assertEq(owrERC20_OR.fundsPendingWithdrawal(), 36 ether);

    //     owrERC20_OR.withdraw(trancheRecipients[1]);

    //     assertEq(mERC20.balanceOf(address(owrERC20_OR)), 32 ether);
    //     assertEq(mERC20.balanceOf(trancheRecipients[0]), 0 ether);
    //     assertEq(mERC20.balanceOf(trancheRecipients[1]), 4 ether);

    //     assertEq(owrERC20_OR.getPullBalance(trancheRecipients[0]), 32 ether);
    //     assertEq(owrERC20_OR.getPullBalance(trancheRecipients[1]), 0 ether);

    //     assertEq(owrERC20_OR.distributedFunds(), 36 ether);
    //     assertEq(owrERC20_OR.fundsPendingWithdrawal(), 32 ether);

    //     owrERC20_OR.withdraw(trancheRecipients[0]);

    //     assertEq(mERC20.balanceOf(address(owrERC20_OR)), 0 ether);
    //     assertEq(mERC20.balanceOf(trancheRecipients[0]), 32 ether);
    //     assertEq(mERC20.balanceOf(trancheRecipients[1]), 4 ether);

    //     assertEq(owrERC20_OR.getPullBalance(trancheRecipients[0]), 0 ether);
    //     assertEq(owrERC20_OR.getPullBalance(trancheRecipients[1]), 0 ether);

    //     assertEq(owrERC20_OR.distributedFunds(), 36 ether);
    //     assertEq(owrERC20_OR.fundsPendingWithdrawal(), 0 ether);
    // }

    // function testCan_waterfallPushAndPull() public {
    //     // test eth
    //     address(owrETH).safeTransferETH(0.5 ether);
    //     assertEq(address(owrETH).balance, 0.5 ether, "incorrect waterfall balance");

    //     owrETH.waterfallFunds();

    //     assertEq(address(owrETH).balance, 0, "incorrect balance");
    //     assertEq(trancheRecipients[0].balance, 0 ether);
    //     assertEq(trancheRecipients[1].balance, 0.5 ether);

    //     assertEq(owrETH.getPullBalance(trancheRecipients[0]), 0 ether);
    //     assertEq(owrETH.getPullBalance(trancheRecipients[1]), 0 ether);

    //     assertEq(owrETH.distributedFunds(), 0.5 ether);
    //     assertEq(owrETH.fundsPendingWithdrawal(), 0 ether);

    //     address(owrETH).safeTransferETH(1 ether);
    //     assertEq(address(owrETH).balance, 1 ether);

    //     owrETH.waterfallFundsPull();

    //     assertEq(address(owrETH).balance, 1 ether);
    //     assertEq(trancheRecipients[0].balance, 0 ether);
    //     assertEq(trancheRecipients[1].balance, 0.5 ether);

    //     assertEq(owrETH.getPullBalance(trancheRecipients[0]), 0 ether);
    //     assertEq(owrETH.getPullBalance(trancheRecipients[1]), 1 ether);

    //     assertEq(owrETH.distributedFunds(), 1.5 ether);
    //     assertEq(owrETH.fundsPendingWithdrawal(), 1 ether);

    //     owrETH.waterfallFunds();

    //     assertEq(address(owrETH).balance, 1 ether);
    //     assertEq(trancheRecipients[0].balance, 0 ether);
    //     assertEq(trancheRecipients[1].balance, 0.5 ether);

    //     assertEq(owrETH.getPullBalance(trancheRecipients[0]), 0);
    //     assertEq(owrETH.getPullBalance(trancheRecipients[1]), 1 ether);

    //     assertEq(owrETH.distributedFunds(), 1.5 ether);
    //     assertEq(owrETH.fundsPendingWithdrawal(), 1 ether);

    //     owrETH.waterfallFundsPull();

    //     assertEq(address(owrETH).balance, 1 ether);
    //     assertEq(trancheRecipients[0].balance, 0 ether);
    //     assertEq(trancheRecipients[1].balance, 0.5 ether);

    //     assertEq(owrETH.getPullBalance(trancheRecipients[0]), 0);
    //     assertEq(owrETH.getPullBalance(trancheRecipients[1]), 1 ether);

    //     assertEq(owrETH.distributedFunds(), 1.5 ether);
    //     assertEq(owrETH.fundsPendingWithdrawal(), 1 ether);

    //     address(owrETH).safeTransferETH(1 ether);
    //     assertEq(address(owrETH).balance, 2 ether);

    //     owrETH.waterfallFunds();

    //     assertEq(address(owrETH).balance, 1 ether);
    //     assertEq(trancheRecipients[0].balance, 0);
    //     assertEq(trancheRecipients[1].balance, 1.5 ether);

    //     assertEq(owrETH.getPullBalance(trancheRecipients[0]), 0 ether);
    //     assertEq(owrETH.getPullBalance(trancheRecipients[1]), 1 ether);

    //     assertEq(owrETH.distributedFunds(), 2.5 ether);
    //     assertEq(owrETH.fundsPendingWithdrawal(), 1 ether);

    //     owrETH.withdraw(trancheRecipients[1]);

    //     assertEq(address(owrETH).balance, 0 ether);
    //     assertEq(trancheRecipients[0].balance, 0);
    //     assertEq(trancheRecipients[1].balance, 2.5 ether);

    //     assertEq(owrETH.getPullBalance(trancheRecipients[0]), 0 ether);
    //     assertEq(owrETH.getPullBalance(trancheRecipients[1]), 0 ether);

    //     assertEq(owrETH.distributedFunds(), 2.5 ether);
    //     assertEq(owrETH.fundsPendingWithdrawal(), 0);
        
    //     address(owrETH).safeTransferETH(1 ether);
    //     owrETH.withdraw(trancheRecipients[1]);

    //     assertEq(address(owrETH).balance, 1 ether);
    //     assertEq(trancheRecipients[0].balance, 0 ether);
    //     assertEq(trancheRecipients[1].balance, 2.5 ether);

    //     assertEq(owrETH.getPullBalance(trancheRecipients[0]), 0 ether);
    //     assertEq(owrETH.getPullBalance(trancheRecipients[1]), 0 ether);

    //     assertEq(owrETH.distributedFunds(), 2.5 ether);
    //     assertEq(owrETH.fundsPendingWithdrawal(), 0 ether);

    //     // TEST ERC20

    //     address(mERC20).safeTransfer(address(owrERC20_OR), 0.5 ether);
    //     assertEq(mERC20.balanceOf(address(owrERC20_OR)), 0.5 ether);

    //     owrERC20_OR.waterfallFunds();

    //     assertEq(mERC20.balanceOf(address(owrERC20_OR)), 0 ether, "1/invalid waterfall balance");
    //     assertEq(mERC20.balanceOf(trancheRecipients[0]), 0 ether, "2/invalid tranche 1 recipient balance");
    //     assertEq(mERC20.balanceOf(trancheRecipients[1]), 0.5 ether, "3/invalid tranche 2 recipient balance - 1");

    //     assertEq(owrERC20_OR.getPullBalance(trancheRecipients[0]), 0 ether, "4/invalid pull balance");
    //     assertEq(owrERC20_OR.getPullBalance(trancheRecipients[1]), 0 ether, "5/invalid pull balance");

    //     assertEq(owrERC20_OR.distributedFunds(), 0.5 ether, "6/invalid distributed funds");
    //     assertEq(owrERC20_OR.fundsPendingWithdrawal(), 0 ether, "7/invalid funds pending withdrawal");

    //     address(mERC20).safeTransfer(address(owrERC20_OR), 1 ether);
    //     assertEq(mERC20.balanceOf(address(owrERC20_OR)), 1 ether, "8/invalid waterfall balance");

    //     owrERC20_OR.waterfallFundsPull();

    //     assertEq(mERC20.balanceOf(address(owrERC20_OR)), 1 ether, "9/invalid waterfall balance");
    //     assertEq(mERC20.balanceOf(trancheRecipients[0]), 0 ether, "10/invalid recipeint balance");
    //     assertEq(mERC20.balanceOf(trancheRecipients[1]), 0.5 ether, "11/invalid recipient balance");

    //     assertEq(owrERC20_OR.getPullBalance(trancheRecipients[0]), 0, "12/invalid recipient pull balance");
    //     assertEq(owrERC20_OR.getPullBalance(trancheRecipients[1]), 1 ether, "13/invalid recipient pull balance");

    //     assertEq(owrERC20_OR.distributedFunds(), 1.5 ether, "14/invalid distributed funds balance");
    //     assertEq(owrERC20_OR.fundsPendingWithdrawal(), 1 ether, "15/invalid funds pending balance");

    //     owrERC20_OR.waterfallFundsPull();

    //     assertEq(mERC20.balanceOf(address(owrERC20_OR)), 1 ether, "16/invalid waterfall balance");
    //     assertEq(mERC20.balanceOf(trancheRecipients[0]), 0 ether, "17/invalid recipient balance");
    //     assertEq(mERC20.balanceOf(trancheRecipients[1]), 0.5 ether, "18/invalid recipient balance");

    //     assertEq(owrERC20_OR.getPullBalance(trancheRecipients[0]), 0 ether, "19/invalid pull balance");
    //     assertEq(owrERC20_OR.getPullBalance(trancheRecipients[1]), 1 ether, "20/invalid pull balance");

    //     assertEq(owrERC20_OR.distributedFunds(), 1.5 ether, "21/invalid distributed funds");
    //     assertEq(owrERC20_OR.fundsPendingWithdrawal(), 1 ether, "22/invalid funds pending");

    //     /// 3
    //     address(mERC20).safeTransfer(address(owrERC20_OR), 32 ether);
    //     assertEq(mERC20.balanceOf(address(owrERC20_OR)), 33 ether);

    //     owrERC20_OR.waterfallFunds();

    //     assertEq(mERC20.balanceOf(address(owrERC20_OR)), 1 ether);
    //     assertEq(mERC20.balanceOf(trancheRecipients[0]), 32 ether);
    //     assertEq(mERC20.balanceOf(trancheRecipients[1]), 0.5 ether);

    //     assertEq(owrERC20_OR.getPullBalance(trancheRecipients[0]), 0 ether);
    //     assertEq(owrERC20_OR.getPullBalance(trancheRecipients[1]), 1 ether);

    //     assertEq(owrERC20_OR.distributedFunds(), 33.5 ether);
    //     assertEq(owrERC20_OR.fundsPendingWithdrawal(), 1 ether);

    //     owrERC20_OR.withdraw(trancheRecipients[1]);

    //     assertEq(mERC20.balanceOf(address(owrERC20_OR)), 0 ether);
    //     assertEq(mERC20.balanceOf(trancheRecipients[0]), 32 ether);
    //     assertEq(mERC20.balanceOf(trancheRecipients[1]), 1.5 ether);

    //     assertEq(owrERC20_OR.getPullBalance(trancheRecipients[0]), 0 ether);
    //     assertEq(owrERC20_OR.getPullBalance(trancheRecipients[1]), 0 ether);

    //     assertEq(owrERC20_OR.distributedFunds(), 33.5 ether);
    //     assertEq(owrERC20_OR.fundsPendingWithdrawal(), 0 ether);
    // }

    // function testFuzzCan_waterfallDepositsToRecipients(
    //     uint256 _recipientsSeed, 
    //     uint256 _thresholdsSeed, 
    //     uint8 _numDeposits, 
    //     uint256 _ethAmount, 
    //     uint256 _erc20Amount 
    // ) public {
    //     _ethAmount = uint256(bound(_ethAmount, 0.01 ether, 34 ether));
    //     _erc20Amount = uint256(bound(_erc20Amount, 0.01 ether, 34 ether));
    //     vm.assume(_numDeposits > 0);
    //     (
    //         address _principalRecipient,
    //         address _rewardRecipient,
    //         uint256 _trancheThreshold
    //     ) = generateTranches(_recipientsSeed, _thresholdsSeed);

    //     owrETH = owrFactory.createOWRecipient(
    //         ETH_ADDRESS,
    //         nonWaterfallRecipient,
    //         _principalRecipient, rewardRecipient,
    //         _trancheThreshold
    //     );

    //     owrERC20 = owrFactory.createOWRecipient(
    //         address(mERC20),
    //         nonWaterfallRecipient,
    //         _principalRecipient, rewardRecipient,
    //         _trancheThreshold
    //     );

    //     /// test eth
    //     for (uint256 i = 0; i < _numDeposits; i++) {
    //         address(owrETH).safeTransferETH(_ethAmount);
    //     }
    //     owrETH.waterfallFunds();


    //     uint256 _totalETHAmount = uint256(_numDeposits) * uint256(_ethAmount);

    //     assertEq(address(owrETH).balance, 0 ether, "invalid balance");
    //     assertEq(owrETH.distributedFunds(), _totalETHAmount, "undistributed funds");
    //     assertEq(owrETH.fundsPendingWithdrawal(), 0 ether, "funds pending withdraw");

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
    //         if (_totalETHAmount > _trancheThreshold) {
    //             // there is reward
    //             assertEq(
    //                 _trancheRecipients[0].balance,
    //                 _trancheThreshold,
    //                 "invalid amount"
    //             );

    //             assertEq(
    //                 _trancheRecipients[1].balance,
    //                 _totalETHAmount - _trancheThreshold,
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

    //     // test erc20

    //     for (uint256 i = 0; i < _numDeposits; i++) {
    //         address(mERC20).safeTransfer(address(owrERC20), _erc20Amount);
    //         owrERC20.waterfallFunds();
    //     }
        
    //     uint256 _totalERC20Amount = uint256(_numDeposits) * uint256(_erc20Amount);

    //     assertEq(mERC20.balanceOf(address(owrERC20)), 0 ether, "invalid erc20 balance");
    //     assertEq(owrERC20.distributedFunds(), _totalERC20Amount, "incorrect distributed funds");
    //     assertEq(owrERC20.fundsPendingWithdrawal(), 0 ether, "invalid funds pending withdrawal");
                
    //     if (BALANCE_CLASSIFICATION_THRESHOLD > _totalERC20Amount) {
    //         // then all of the deposit should be classified as reward
    //         assertEq(
    //             mERC20.balanceOf(_trancheRecipients[0]),
    //             0,
    //             "should not classify reward as principal"
    //         );

    //         assertEq(
    //             mERC20.balanceOf(_trancheRecipients[1]),
    //             _totalERC20Amount,
    //             "invalid amount reward classification"
    //         );
    //     }

    //     if (_erc20Amount > BALANCE_CLASSIFICATION_THRESHOLD) {
    //         // then all of reward classified as principal
    //         // but check if _totalERC20Amount > first threshold
    //         if (_totalERC20Amount > _trancheThreshold) {
    //             // there is reward
    //             assertEq(
    //                 mERC20.balanceOf(_trancheRecipients[0]),
    //                 _trancheThreshold,
    //                 "invalid amount principal classification"
    //             );

    //             assertEq(
    //                 mERC20.balanceOf(_trancheRecipients[1]),
    //                 _totalERC20Amount - _trancheThreshold,
    //                 "should not classify principal as reward"
    //             );
    //         } else {
    //             // eelse no rewards
    //             assertEq(
    //                 mERC20.balanceOf(_trancheRecipients[0]),
    //                 _totalERC20Amount,
    //                 "invalid amount"
    //             );

    //             assertEq(
    //                mERC20.balanceOf(_trancheRecipients[1]),
    //                 0,
    //                 "should not classify principal as reward"
    //             );
    //         }
    //     }
    // }

    // function testFuzzCan_waterfallPullDepositsToRecipients(
    //     uint256 _recipientsSeed,
    //     uint256 _thresholdsSeed,
    //     uint8 _numDeposits,
    //     uint256 _ethAmount,
    //     uint256 _erc20Amount
    // ) public {
    //     _ethAmount = uint256(bound(_ethAmount, 0.01 ether, 40 ether));
    //     _erc20Amount = uint256(bound(_erc20Amount, 0.01 ether, 40 ether));
    //     vm.assume(_numDeposits > 0);

    //     (
    //         address _principalRecipient,
    //         address _rewardRecipient,
    //         uint256 _trancheThreshold
    //     ) = generateTranches(_recipientsSeed, _thresholdsSeed);

    //     owrETH = owrFactory.createOWRecipient(
    //         ETH_ADDRESS,
    //         nonWaterfallRecipient,
    //         _principalRecipient, rewardRecipient,
    //         _trancheThreshold
    //     );
    //     owrERC20 = owrFactory.createOWRecipient(
    //         address(mERC20),
    //         nonWaterfallRecipient,
    //         _principalRecipient,
    //         _rewardRecipient,
    //         _trancheThreshold
    //     );

    //     /// test eth

    //     for (uint256 i = 0; i < _numDeposits; i++) {
    //         address(owrETH).safeTransferETH(_ethAmount);
    //         owrETH.waterfallFundsPull();
    //     }
    //     uint256 _totalETHAmount = uint256(_numDeposits) * uint256(_ethAmount);

    //     assertEq(address(owrETH).balance, _totalETHAmount);
    //     assertEq(owrETH.distributedFunds(), _totalETHAmount);
    //     assertEq(owrETH.fundsPendingWithdrawal(), _totalETHAmount);

    //     uint256 principal = owrETH.getPullBalance(_principalRecipient);
    //     assertEq(
    //         owrETH.getPullBalance(_principalRecipient),
    //         (_ethAmount >= BALANCE_CLASSIFICATION_THRESHOLD)
    //             ? _trancheThreshold > _totalETHAmount ? _totalETHAmount : _trancheThreshold
    //             : 0
    //         ,
    //         "5/invalid recipient balance"
    //     );

    //     uint256 reward = owrETH.getPullBalance(_rewardRecipient);
    //     assertEq(
    //         owrETH.getPullBalance(_trancheRecipients[1]),
    //         (_ethAmount >= BALANCE_CLASSIFICATION_THRESHOLD)
    //             ? _totalETHAmount > _trancheThreshold ? (_totalETHAmount - _trancheThreshold) : 0
    //             : _totalETHAmount
    //         ,
    //         "6/invalid recipient balance"
    //     );

        
    //     owrETH.withdraw(_trancheRecipients[0]);
    //     owrETH.withdraw(_trancheRecipients[1]);


    //     assertEq(address(owrETH).balance, 0);
    //     assertEq(owrETH.distributedFunds(), _totalETHAmount);
    //     assertEq(owrETH.fundsPendingWithdrawal(), 0);

    //     assertEq(_trancheRecipients[0].balance, principal, "10/invalid principal balance");
    //     assertEq(_trancheRecipients[1].balance, reward, "11/invalid reward balance");

    //     /// test erc20

    //     for (uint256 i = 0; i < _numDeposits; i++) {
    //         address(mERC20).safeTransfer(address(owrERC20), _erc20Amount);
    //         owrERC20.waterfallFundsPull();
    //     }
    //     uint256 _totalERC20Amount =
    //         uint256(_numDeposits) * uint256(_erc20Amount);

    //     assertEq(mERC20.balanceOf(address(owrERC20)), _totalERC20Amount);
    //     assertEq(owrERC20.distributedFunds(), _totalERC20Amount);
    //     assertEq(owrERC20.fundsPendingWithdrawal(), _totalERC20Amount);

    //     principal = owrERC20.getPullBalance(_trancheRecipients[0]);
    //     assertEq(
    //         owrERC20.getPullBalance(_trancheRecipients[0]),
    //         (_erc20Amount >= BALANCE_CLASSIFICATION_THRESHOLD)
    //             ? _trancheThreshold > _totalERC20Amount ? _totalERC20Amount : _trancheThreshold
    //             : 0
    //         ,
    //         "16/invalid recipient balance"
    //     );

    //     reward = owrERC20.getPullBalance(_trancheRecipients[1]);
    //     assertEq(
    //         owrERC20.getPullBalance(_trancheRecipients[1]),
    //         (_erc20Amount >= BALANCE_CLASSIFICATION_THRESHOLD)
    //             ? _totalERC20Amount > _trancheThreshold ? (_totalERC20Amount - _trancheThreshold) : 0
    //             : _totalERC20Amount
    //         ,
    //         "17/invalid recipient balance"
    //     );

    //     owrERC20.withdraw(_trancheRecipients[0]);
    //     owrERC20.withdraw(_trancheRecipients[1]);


    //     assertEq(mERC20.balanceOf(address(owrERC20)), 0, "18/invalid balance");
    //     assertEq(owrERC20.distributedFunds(), _totalERC20Amount, "19/invalid balance");
    //     assertEq(owrERC20.fundsPendingWithdrawal(), 0, "20/invalid funds pending");

    //     assertEq(mERC20.balanceOf(_trancheRecipients[0]), principal, "21/invalid principal balance");
    //     assertEq(mERC20.balanceOf(_trancheRecipients[1]), reward, "22/invalid reward balance");
    // }

}