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

    uint256 constant MAX_TRANCHE_SIZE = 2;
    uint256 constant BALANCE_CLASSIFICATION_THRESHOLD = 16 ether;
    
    WaterfallModule public waterfallModule;
    WaterfallModuleFactory public waterfallModuleFactory;
    address public nonWaterfallRecipient;

    WaterfallModule waterfallModuleETH;
    WaterfallModule waterfallModuleERC20;
    MockERC20 mERC20;


    function setUp() public {
        waterfallModuleFactory = new WaterfallModuleFactory();
        waterfallModule = waterfallModuleFactory.wmImpl();

        mERC20 = new MockERC20("demo", "DMT", 18);
    }

    function testP() public {
        console.logString("checking");
        console.log(type(uint96).max);
        console.log(type(uint96).max / 1 ether);
    }

    function test_fuzz_waterfallDepositsToRecipients(
        uint256 _recipientsSeed,
        uint256 _thresholdsSeed,
        uint8 _numDeposits,
        uint64 _ethAmount,
        uint96 _erc20Amount
    ) public {
        (
            address[] memory _trancheRecipients,
            uint256[] memory _trancheThresholds
        ) = generateTranches(_recipientsSeed, _thresholdsSeed);

        waterfallModuleETH = waterfallModuleFactory.createWaterfallModule(
            ETH_ADDRESS,
            nonWaterfallRecipient,
            _trancheRecipients,
            _trancheThresholds
        );

        waterfallModuleERC20 = waterfallModuleFactory.createWaterfallModule(
            address(mERC20),
            nonWaterfallRecipient,
            _trancheRecipients,
            _trancheThresholds
        );

        /// test eth
        for (uint256 i = 0; i < _numDeposits; i++) {
            address(waterfallModuleETH).safeTransferETH(_ethAmount);
            waterfallModuleETH.waterfallFunds();
        }

        uint256 _totalETHAmount = uint256(_numDeposits) * uint256(_ethAmount);

        assertEq(address(waterfallModuleETH).balance, 0 ether);
        assertEq(waterfallModuleETH.distributedFunds(), _totalETHAmount);
        assertEq(waterfallModuleETH.fundsPendingWithdrawal(), 0 ether);

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
            if (_totalETHAmount > _trancheThresholds[0]) {
                // there is reward
                assertEq(
                    _trancheRecipients[0].balance,
                    _trancheThresholds[0],
                    "invalid amount"
                );

                assertEq(
                    _trancheRecipients[1].balance,
                    _totalETHAmount - _trancheThresholds[0],
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

        // if ()

        // assertEq(
        //     _trancheRecipients[0].balance,
        //     (_totalETHAmount >= _trancheThresholds[0])
        //         ? _trancheThresholds[0]
        //         : _totalETHAmount
        // );
        // for (uint256 i = 1; i < _trancheThresholds.length; i++) {
        // if (_totalETHAmount >= _trancheThresholds[i]) {
        //     assertEq(
        //         _trancheRecipients[i].balance,
        //         _trancheThresholds[i] - _trancheThresholds[i - 1]
        //     );
        // } else if (_totalETHAmount > _trancheThresholds[i - 1]) {
        //     assertEq(
        //         _trancheRecipients[i].balance,
        //         _totalETHAmount - _trancheThresholds[i - 1]
        //     );
        // } else {
        //     assertEq(_trancheRecipients[i].balance, 0);
        // }
        // // }
        // assertEq(
        //     _trancheRecipients[_trancheRecipients.length - 1].balance,
        //     (
        //         _totalETHAmount
        //             > _trancheThresholds[_trancheRecipients.length - 2]
        //     )
        //         ? _totalETHAmount
        //             - _trancheThresholds[_trancheRecipients.length - 2]
        //         : 0
        // );

        // /// test erc20

        // for (uint256 i = 0; i < _numDeposits; i++) {
        //     address(mERC20).safeTransfer(address(wmERC20), _erc20Amount);
        //     wmERC20.waterfallFunds();
        // }
        // uint256 _totalERC20Amount =
        //     uint256(_numDeposits) * uint256(_erc20Amount);

        // assertEq(mERC20.balanceOf(address(wmERC20)), 0 ether);
        // assertEq(wmERC20.distributedFunds(), _totalERC20Amount);
        // assertEq(wmERC20.fundsPendingWithdrawal(), 0 ether);
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
    }

    /// -----------------------------------------------------------------------
    /// helper fns
    /// -----------------------------------------------------------------------

    function generateTranches(uint256 rSeed, uint256 tSeed)
        internal
        pure
        returns (address[] memory recipients, uint256[] memory thresholds)
    {
        recipients = generateTrancheRecipients(MAX_TRANCHE_SIZE, rSeed);
        thresholds = generateTrancheThresholds(MAX_TRANCHE_SIZE - 1, tSeed);
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

    function generateTrancheThresholds(uint256 numThresholds, uint256 _seed)
        internal
        pure
        returns (uint256[] memory thresholds)
    {
        thresholds = new uint256[](numThresholds);
        uint256 seed = _seed;
        seed = uint256(keccak256(abi.encodePacked(seed)));
        thresholds[0] = uint32(seed);
        // for (uint256 i = 1; i < numThresholds; i++) {
        //     seed = uint256(keccak256(abi.encodePacked(seed)));
        //     thresholds[i] = thresholds[i - 1] + uint32(seed);
        // }
    }
}