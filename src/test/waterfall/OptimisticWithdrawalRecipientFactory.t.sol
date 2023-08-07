// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import { OptimisticWithdrawalRecipient } from "src/waterfall/OptimisticWithdrawalRecipient.sol";
import { OptimisticWithdrawalRecipientFactory } from "src/waterfall/OptimisticWithdrawalRecipientFactory.sol";
import {MockERC20} from "../utils/mocks/MockERC20.sol";
import {WaterfallTestHelper} from "./WaterfallTestHelper.t.sol";

contract OptimisticWithdrawalRecipientFactoryTest is WaterfallTestHelper, Test {


    event CreateOWRecipient(
         address indexed owr,
        address token,
        address nonOWRecipient,
        address principalRecipient,
        address rewardRecipient,
        uint256 threshold
    );

    OptimisticWithdrawalRecipientFactory owrFactoryModule;
    MockERC20 mERC20;

    address public nonWaterfallRecipient;
    address public principalRecipient;
    address public rewardRecipient;
    uint256 public threshold;

    function setUp() public {
        mERC20 = new MockERC20("Test Token", "TOK", 18);
        mERC20.mint(type(uint256).max);

        owrFactoryModule = new OptimisticWithdrawalRecipientFactory();

        nonWaterfallRecipient = makeAddr("nonWaterfallRecipient");
        recipients = generateTrancheRecipients(2, 10);
        threshold = ETH_STAKE;
    }

    function testCan_createWaterfallModules() public {
        owrFactoryModule.createOWRecipient(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );

        owrFactoryModule.createOWRecipient(
            address(mERC20), nonWaterfallRecipient, recipients, threshold
        );

        nonWaterfallRecipient = address(0);
        owrFactoryModule.createOWRecipient(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );

        owrFactoryModule.createOWRecipient(
            address(mERC20), nonWaterfallRecipient, recipients, threshold
        );
    }


    function testCan_emitOnCreate() public {
        // don't check deploy address
        vm.expectEmit(false, true, true, true);
        emit CreateOWRecipient(
            address(0xdead),
            ETH_ADDRESS,
            nonWaterfallRecipient,
            recipients,
            threshold
            );
        owrFactoryModule.createWaterfallModule(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );

        // don't check deploy address
        vm.expectEmit(false, true, true, true);
        emit CreateOWRecipient(
            address(0xdead),
            address(mERC20),
            nonWaterfallRecipient,
            recipients,
            threshold
            );
        owrFactoryModule.createWaterfallModule(
            address(mERC20), nonWaterfallRecipient, recipients, threshold
        );

        nonWaterfallRecipient = address(0);

        // don't check deploy address
        vm.expectEmit(false, true, true, true);
        emit CreateOWRecipient(
            address(0xdead),
            ETH_ADDRESS,
            nonWaterfallRecipient,
            recipients,
            threshold
            );
        owrFactoryModule.createWaterfallModule(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );

        // don't check deploy address
        vm.expectEmit(false, true, true, true);
        emit CreateOWRecipient(
            address(0xdead),
            address(mERC20),
            nonWaterfallRecipient,
            recipients,
            threshold
            );
        owrFactoryModule.createWaterfallModule(
            address(mERC20), nonWaterfallRecipient, recipients, threshold
        );
    }

    function testCannot_createWithTooFewRecipients() public {
        (recipients, threshold) = generateTranches(1, 1);
        recipients = generateTrancheRecipients(1, 1);

        vm.expectRevert(
            OptimisticWithdrawalRecipientFactory.InvalidWaterfall__Recipients.selector
        );
        owrFactoryModule.createWaterfallModule(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );

        recipients = generateTrancheRecipients(3, 10);
        vm.expectRevert(
            OptimisticWithdrawalRecipientFactory.InvalidWaterfall__Recipients.selector
        );
        owrFactoryModule.createWaterfallModule(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );
    }

    function testCannot_createWithInvalidThreshold() public {
        recipients = generateTrancheRecipients(2, 2);
        threshold = 0;

        vm.expectRevert(
            OptimisticWithdrawalRecipientFactory
                .InvalidWaterfall__ZeroThreshold
                .selector
        );
        owrFactoryModule.createWaterfallModule(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );

        vm.expectRevert(
            abi.encodeWithSelector(OptimisticWithdrawalRecipientFactory
                .InvalidWaterfall__ThresholdTooLarge
                .selector,
                type(uint128).max
            )
        );
        owrFactoryModule.createWaterfallModule(
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
        emit CreateOWRecipient(
            address(0xdead),
            ETH_ADDRESS,
            nonWaterfallRecipient,
            recipients,
            threshold
        );
        owrFactoryModule.createWaterfallModule(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );

        vm.expectEmit(false, true, true, true);
        emit CreateOWRecipient(
            address(0xdead),
            address(mERC20),
            nonWaterfallRecipient,
            recipients,
            threshold
        );
        owrFactoryModule.createWaterfallModule(
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
            OptimisticWithdrawalRecipientFactory.Invalid__Recipients.selector
        );
        owrFactoryModule.createWaterfallModule(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );

        vm.expectRevert(
            OptimisticWithdrawalRecipientFactory.Invalid__Recipients.selector
        );

        owrFactoryModule.createWaterfallModule(
            address(mERC20), nonWaterfallRecipient, recipients, threshold
        );
    }

    function testFuzzCannot_CreateWithZeroThreshold(
        uint256 _receipientSeed
    ) public {
        threshold = 0;
        recipients = generateTrancheRecipients(2, _receipientSeed);

        // eth
        vm.expectRevert(
            OptimisticWithdrawalRecipientFactory.Invalid__ZeroThreshold.selector
        );
        owrFactoryModule.createWaterfallModule(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );

        // erc20
        vm.expectRevert(
            OptimisticWithdrawalRecipientFactory.Invalid__ZeroThreshold.selector
        );

        owrFactoryModule.createWaterfallModule(
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
            abi.encodeWithSelector(OptimisticWithdrawalRecipientFactory
                .InvalidWaterfall__ThresholdTooLarge
                .selector,
                _threshold
            )
        );
        
        owrFactoryModule.createWaterfallModule(
            ETH_ADDRESS, nonWaterfallRecipient, recipients, threshold
        );


        vm.expectRevert(
            abi.encodeWithSelector(OptimisticWithdrawalRecipientFactory
                .InvalidWaterfall__ThresholdTooLarge
                .selector,
                _threshold
            )
        );
        
        owrFactoryModule.createWaterfallModule(
            address(mERC20), nonWaterfallRecipient, recipients, threshold
        );

    }


}