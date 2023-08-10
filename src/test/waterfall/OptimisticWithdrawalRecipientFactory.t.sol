// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import { OptimisticWithdrawalRecipient } from "src/waterfall/OptimisticWithdrawalRecipient.sol";
import { OptimisticWithdrawalRecipientFactory } from "src/waterfall/OptimisticWithdrawalRecipientFactory.sol";
import {MockERC20} from "../utils/mocks/MockERC20.sol";
import {OWRTestHelper} from "./OWRTestHelper.t.sol";

contract OptimisticWithdrawalRecipientFactoryTest is OWRTestHelper, Test {


    event CreateOWRecipient(
        address indexed owr,
        address token,
        address recoveryAddress,
        address principalRecipient,
        address rewardRecipient,
        uint256 threshold
    );

    OptimisticWithdrawalRecipientFactory owrFactoryModule;
    MockERC20 mERC20;

    address public recoveryAddress;
    address public principalRecipient;
    address public rewardRecipient;
    uint256 public threshold;

    function setUp() public {
        mERC20 = new MockERC20("Test Token", "TOK", 18);
        mERC20.mint(type(uint256).max);

        owrFactoryModule = new OptimisticWithdrawalRecipientFactory();

        recoveryAddress = makeAddr("recoveryAddress");
        (principalRecipient, rewardRecipient) = generateTrancheRecipients(10);
        threshold = ETH_STAKE;
    }

    function testCan_createOWRecipient() public {
        owrFactoryModule.createOWRecipient(
            ETH_ADDRESS, recoveryAddress, principalRecipient, rewardRecipient, threshold
        );

        owrFactoryModule.createOWRecipient(
            address(mERC20), recoveryAddress, principalRecipient, rewardRecipient, threshold
        );

        recoveryAddress = address(0);
        owrFactoryModule.createOWRecipient(
            ETH_ADDRESS, recoveryAddress, principalRecipient, rewardRecipient, threshold
        );

        owrFactoryModule.createOWRecipient(
            address(mERC20), recoveryAddress, principalRecipient, rewardRecipient, threshold
        );
    }


    function testCan_emitOnCreate() public {
        // don't check deploy address
        vm.expectEmit(false, true, true, true);
        emit CreateOWRecipient(
            address(0xdead),
            ETH_ADDRESS,
            recoveryAddress,
            principalRecipient, rewardRecipient,
            threshold
            );
        owrFactoryModule.createOWRecipient(
            ETH_ADDRESS, recoveryAddress, principalRecipient, rewardRecipient, threshold
        );

        // don't check deploy address
        vm.expectEmit(false, true, true, true);
        emit CreateOWRecipient(
            address(0xdead),
            address(mERC20),
            recoveryAddress,
            principalRecipient, rewardRecipient,
            threshold
            );
        owrFactoryModule.createOWRecipient(
            address(mERC20), recoveryAddress, principalRecipient, rewardRecipient, threshold
        );

        recoveryAddress = address(0);

        // don't check deploy address
        vm.expectEmit(false, true, true, true);
        emit CreateOWRecipient(
            address(0xdead),
            ETH_ADDRESS,
            recoveryAddress,
            principalRecipient, rewardRecipient,
            threshold
            );
        owrFactoryModule.createOWRecipient(
            ETH_ADDRESS, recoveryAddress, principalRecipient, rewardRecipient, threshold
        );

        // don't check deploy address
        vm.expectEmit(false, true, true, true);
        emit CreateOWRecipient(
            address(0xdead),
            address(mERC20),
            recoveryAddress,
            principalRecipient, rewardRecipient,
            threshold
            );
        owrFactoryModule.createOWRecipient(
            address(mERC20), recoveryAddress, principalRecipient, rewardRecipient, threshold
        );
    }

    function testCannot_createWithInvalidRecipients() public {
        (principalRecipient, rewardRecipient, threshold) = generateTranches(1, 1);
        // eth
        vm.expectRevert(
            OptimisticWithdrawalRecipientFactory.Invalid__Recipients.selector
        );
        owrFactoryModule.createOWRecipient(
            ETH_ADDRESS, recoveryAddress, address(0), rewardRecipient, threshold
        );

        vm.expectRevert(
            OptimisticWithdrawalRecipientFactory.Invalid__Recipients.selector
        );
        owrFactoryModule.createOWRecipient(
            ETH_ADDRESS, recoveryAddress, address(0), address(0), threshold
        );

        vm.expectRevert(
            OptimisticWithdrawalRecipientFactory.Invalid__Recipients.selector
        );
        owrFactoryModule.createOWRecipient(
            ETH_ADDRESS, recoveryAddress, principalRecipient, address(0), threshold
        );

        // erc20
        vm.expectRevert(
            OptimisticWithdrawalRecipientFactory.Invalid__Recipients.selector
        );
        owrFactoryModule.createOWRecipient(
            address(mERC20), recoveryAddress, address(0), rewardRecipient, threshold
        );

        vm.expectRevert(
            OptimisticWithdrawalRecipientFactory.Invalid__Recipients.selector
        );
        owrFactoryModule.createOWRecipient(
            address(mERC20), recoveryAddress, address(0), address(0), threshold
        );

        vm.expectRevert(
            OptimisticWithdrawalRecipientFactory.Invalid__Recipients.selector
        );
        owrFactoryModule.createOWRecipient(
            address(mERC20), recoveryAddress, principalRecipient, address(0), threshold
        );
    }

    function testCannot_createWithInvalidThreshold() public {
        (principalRecipient, rewardRecipient) = generateTrancheRecipients(2);
        threshold = 0;

        vm.expectRevert(
            OptimisticWithdrawalRecipientFactory
                .Invalid__ZeroThreshold
                .selector
        );
        owrFactoryModule.createOWRecipient(
            ETH_ADDRESS, recoveryAddress, principalRecipient, rewardRecipient, threshold
        );

        vm.expectRevert(
            abi.encodeWithSelector(OptimisticWithdrawalRecipientFactory
                .Invalid__ThresholdTooLarge
                .selector,
                type(uint128).max
            )
        );
        owrFactoryModule.createOWRecipient(
            ETH_ADDRESS, recoveryAddress, principalRecipient, rewardRecipient, type(uint128).max
        );
    }


    /// -----------------------------------------------------------------------
    /// Fuzzing Tests
    /// ----------------------------------------------------------------------

    function testFuzzCan_createOWRecipient(
        address _recoveryAddress,
        uint256 recipientsSeed,
        uint256 thresholdSeed
    ) public {
        recoveryAddress = _recoveryAddress;

        (principalRecipient, rewardRecipient, threshold) = generateTranches(recipientsSeed, thresholdSeed);
        
        vm.expectEmit(false, true, true, true);
        emit CreateOWRecipient(
            address(0xdead),
            ETH_ADDRESS,
            recoveryAddress,
            principalRecipient, rewardRecipient,
            threshold
        );
        owrFactoryModule.createOWRecipient(
            ETH_ADDRESS, recoveryAddress, principalRecipient, rewardRecipient, threshold
        );

        vm.expectEmit(false, true, true, true);
        emit CreateOWRecipient(
            address(0xdead),
            address(mERC20),
            recoveryAddress,
            principalRecipient, rewardRecipient,
            threshold
        );
        owrFactoryModule.createOWRecipient(
            address(mERC20), recoveryAddress, principalRecipient, rewardRecipient, threshold
        );
    }

    function testFuzzCannot_CreateWithZeroThreshold(
        uint256 _receipientSeed
    ) public {
        threshold = 0;
        (principalRecipient, rewardRecipient) = generateTrancheRecipients(_receipientSeed);

        // eth
        vm.expectRevert(
            OptimisticWithdrawalRecipientFactory.Invalid__ZeroThreshold.selector
        );
        owrFactoryModule.createOWRecipient(
            ETH_ADDRESS, recoveryAddress, principalRecipient, rewardRecipient, threshold
        );

        // erc20
        vm.expectRevert(
            OptimisticWithdrawalRecipientFactory.Invalid__ZeroThreshold.selector
        );

        owrFactoryModule.createOWRecipient(
            address(mERC20), recoveryAddress, principalRecipient, rewardRecipient, threshold
        );
    }

    function testFuzzCannot_CreateWithLargeThreshold(
        uint256 _receipientSeed,
        uint256 _threshold
    ) public {
        vm.assume(_threshold > type(uint96).max);
        
        threshold = _threshold;
        (principalRecipient, rewardRecipient) = generateTrancheRecipients(_receipientSeed);

        vm.expectRevert(
            abi.encodeWithSelector(OptimisticWithdrawalRecipientFactory
                .Invalid__ThresholdTooLarge
                .selector,
                _threshold
            )
        );
        
        owrFactoryModule.createOWRecipient(
            ETH_ADDRESS, recoveryAddress, principalRecipient, rewardRecipient, threshold
        );


        vm.expectRevert(
            abi.encodeWithSelector(OptimisticWithdrawalRecipientFactory
                .Invalid__ThresholdTooLarge
                .selector,
                _threshold
            )
        );
        
        owrFactoryModule.createOWRecipient(
            address(mERC20), recoveryAddress, principalRecipient, rewardRecipient, threshold
        );

    }


}