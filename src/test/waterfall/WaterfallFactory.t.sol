// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import { WaterfallModule } from "src/waterfall/WaterfallModule.sol";
import { WaterfallModuleFactory } from "src/waterfall/WaterfallModuleFactory.sol";
import {MockERC20} from "../utils/mocks/MockERC20.sol";
import {WaterfallTestHelper} from "./WaterfallTestHelper.t.sol";

contract WaterfallModuleFactoryTest is WaterfallTestHelper, Test {


    event CreateWaterfallModule(
        address indexed waterfallModule,
        address token,
        address nonWaterfallRecipient,
        address[] trancheRecipient,
        uint256 trancheThreshold
    );

    WaterfallModuleFactory waterfallFactoryModule;
    MockERC20 mERC20;

    address public nonWaterfallRecipient;
    address[] public recipients;
    uint256 public threshold;

    function setUp() public {
        mERC20 = new MockERC20("Test Token", "TOK", 18);
        mERC20.mint(type(uint256).max);

        waterfallFactoryModule = new WaterfallModuleFactory();

        nonWaterfallRecipient = makeAddr("nonWaterfallRecipient");
        recipients = generateTrancheRecipients(2, 10);
        threshold = ETH_STAKE;
    }

    function testCan_createWaterfallModules() public {
        waterfallFactoryModule.createWaterfallModule(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );

        waterfallFactoryModule.createWaterfallModule(
            address(mERC20), nonWaterfallRecipient, recipients, threshold
        );

        nonWaterfallRecipient = address(0);
        waterfallFactoryModule.createWaterfallModule(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );

        waterfallFactoryModule.createWaterfallModule(
            address(mERC20), nonWaterfallRecipient, recipients, threshold
        );
    }


    function testCan_emitOnCreate() public {
        // don't check deploy address
        vm.expectEmit(false, true, true, true);
        emit CreateWaterfallModule(
            address(0xdead),
            ETH_ADDRESS,
            nonWaterfallRecipient,
            recipients,
            threshold
            );
        waterfallFactoryModule.createWaterfallModule(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );

        // don't check deploy address
        vm.expectEmit(false, true, true, true);
        emit CreateWaterfallModule(
            address(0xdead),
            address(mERC20),
            nonWaterfallRecipient,
            recipients,
            threshold
            );
        waterfallFactoryModule.createWaterfallModule(
            address(mERC20), nonWaterfallRecipient, recipients, threshold
        );

        nonWaterfallRecipient = address(0);

        // don't check deploy address
        vm.expectEmit(false, true, true, true);
        emit CreateWaterfallModule(
            address(0xdead),
            ETH_ADDRESS,
            nonWaterfallRecipient,
            recipients,
            threshold
            );
        waterfallFactoryModule.createWaterfallModule(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );

        // don't check deploy address
        vm.expectEmit(false, true, true, true);
        emit CreateWaterfallModule(
            address(0xdead),
            address(mERC20),
            nonWaterfallRecipient,
            recipients,
            threshold
            );
        waterfallFactoryModule.createWaterfallModule(
            address(mERC20), nonWaterfallRecipient, recipients, threshold
        );
    }

    function testCannot_createWithTooFewRecipients() public {
        (recipients, threshold) = generateTranches(1, 1);
        recipients = generateTrancheRecipients(1, 1);

        vm.expectRevert(
            WaterfallModuleFactory.InvalidWaterfall__Recipients.selector
        );
        waterfallFactoryModule.createWaterfallModule(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );

        recipients = generateTrancheRecipients(3, 10);
        vm.expectRevert(
            WaterfallModuleFactory.InvalidWaterfall__Recipients.selector
        );
        waterfallFactoryModule.createWaterfallModule(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );
    }

    function testCannot_createWithInvalidThreshold() public {
        recipients = generateTrancheRecipients(2, 2);
        threshold = 0;

        vm.expectRevert(
            WaterfallModuleFactory
                .InvalidWaterfall__ZeroThreshold
                .selector
        );
        waterfallFactoryModule.createWaterfallModule(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );

        vm.expectRevert(
            abi.encodeWithSelector(WaterfallModuleFactory
                .InvalidWaterfall__ThresholdTooLarge
                .selector,
                type(uint128).max
            )
        );
        waterfallFactoryModule.createWaterfallModule(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, type(uint128).max
        );
    }


    /// -----------------------------------------------------------------------
    /// Fuzzing Tests
    /// ----------------------------------------------------------------------

    function testFuzzCan_createWaterfallModules(
        address _nonWaterfallRecipient,
        uint256 recipientsSeed,
        uint256 thresholdSeed
    ) public {
        nonWaterfallRecipient = _nonWaterfallRecipient;

        (recipients, threshold) = generateTranches(recipientsSeed, thresholdSeed);
        
        vm.expectEmit(false, true, true, true);
        emit CreateWaterfallModule(
            address(0xdead),
            ETH_ADDRESS,
            nonWaterfallRecipient,
            recipients,
            threshold
        );
        waterfallFactoryModule.createWaterfallModule(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );

        vm.expectEmit(false, true, true, true);
        emit CreateWaterfallModule(
            address(0xdead),
            address(mERC20),
            nonWaterfallRecipient,
            recipients,
            threshold
        );
        waterfallFactoryModule.createWaterfallModule(
            address(mERC20), nonWaterfallRecipient, recipients, threshold
        );
    }


    function testFuzzCannot_CreateWithInvalidFewRecipients(
        uint8 _numRecipeints,
        uint256 _receipientSeed
    ) public {
        vm.assume(_numRecipeints != 2);
        recipients = generateTrancheRecipients(_numRecipeints, _receipientSeed);

        vm.expectRevert(
            WaterfallModuleFactory.InvalidWaterfall__Recipients.selector
        );
        waterfallFactoryModule.createWaterfallModule(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );

        vm.expectRevert(
            WaterfallModuleFactory.InvalidWaterfall__Recipients.selector
        );

        waterfallFactoryModule.createWaterfallModule(
            address(mERC20), nonWaterfallRecipient, recipients, threshold
        );
    }

    function testFuzzCannot_CreateWithZeroThreshold(
        uint256 _receipientSeed
    ) public {
        threshold = 0;
        recipients = generateTrancheRecipients(2, _receipientSeed);

        vm.expectRevert(
            WaterfallModuleFactory.InvalidWaterfall__ZeroThreshold.selector
        );
        waterfallFactoryModule.createWaterfallModule(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );

        vm.expectRevert(
            WaterfallModuleFactory.InvalidWaterfall__ZeroThreshold.selector
        );

        waterfallFactoryModule.createWaterfallModule(
            address(mERC20), nonWaterfallRecipient, recipients, threshold
        );
    }

    function testFuzzCannot_CreateWithLargeThreshold(
        uint256 _receipientSeed,
        uint256 _threshold
    ) public {
        vm.assume(_threshold > type(uint96).max);
        
        threshold = _threshold;
        recipients = generateTrancheRecipients(2, _receipientSeed);

        vm.expectRevert(
            abi.encodeWithSelector(WaterfallModuleFactory
                .InvalidWaterfall__ThresholdTooLarge
                .selector,
                _threshold
            )
        );
        
        waterfallFactoryModule.createWaterfallModule(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );


        vm.expectRevert(
            abi.encodeWithSelector(WaterfallModuleFactory
                .InvalidWaterfall__ThresholdTooLarge
                .selector,
                _threshold
            )
        );
        
        waterfallFactoryModule.createWaterfallModule(
            address(mERC20), nonWaterfallRecipient, recipients, threshold
        );

    }


}