// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {IETHPOSDeposit} from "src/interfaces/IETHPOSDeposit.sol";
import { ETHPOSDepositMock } from "../utils/mocks/ETHDepositMock.sol";
import { ObolCapsule, ObolCapsuleFactory, IObolCapsuleFactory } from "src/capsule/ObolCapsuleFactory.sol";
import {ObolCapsuleBeacon} from "src/capsule/ObolCapsuleBeacon.sol";

contract ObolCapsuleFactoryTest is Test {

    ObolCapsuleFactory public obolCapsuleFactory;
    ObolCapsule public createdObolCapsuleImplementation;
    ObolCapsuleBeacon public obolCapsuleBeacon;
    ETHPOSDepositMock ethPOSDepositMock;

    uint256 constant public genesisTime = 1;

    error Unauthorized();
    error Invalid__Address();
    error Invalid__RewardRecipient();
    error Invalid__PrincipalRecipient();
    error Invalid__RecoveryRecipient();


    event CreateCapsule(
        address indexed capsule,
        address principalRecipient,
        address rewardRecipient,
        address recoveryRecipient
    );
//     event UpdateStateProofVerifier(
//         address indexed oldVerifier,
//         address newVerifier
//     );

    uint256 feeShare;
    address rewardRecipient;
    address principalRecipient;
    address recoveryRecipient;
    address feeRecipient;
    address owner;


    function setUp() public {
        feeRecipient       = makeAddr("feeRecipient");
        rewardRecipient    = makeAddr("rewardRecipient");
        principalRecipient = makeAddr("principalRecipient");
        recoveryRecipient  = makeAddr("recoveryRecipient");

        owner = makeAddr("owner");
        feeShare = 10_000;

        ethPOSDepositMock = new ETHPOSDepositMock();
        createdObolCapsuleImplementation = new ObolCapsule(
            IETHPOSDeposit(ethPOSDepositMock),
            genesisTime,
            feeRecipient,
            feeShare
        );

        obolCapsuleBeacon = new ObolCapsuleBeacon(
            address(createdObolCapsuleImplementation),
            owner
        );
        
        obolCapsuleFactory = new ObolCapsuleFactory(
            address(obolCapsuleBeacon)
        );
    }

    function test_CreateCapsule() external {
        address predictedAddress = obolCapsuleFactory.predictCapsuleAddress(
            principalRecipient,
            rewardRecipient,
            recoveryRecipient
        );

        vm.expectEmit(false, false, false, true);
        emit CreateCapsule(predictedAddress, principalRecipient, rewardRecipient, recoveryRecipient);
        
        obolCapsuleFactory.createCapsule(
            principalRecipient,
            rewardRecipient,
            recoveryRecipient
        );

        assertEq(
            ObolCapsule(predictedAddress).principalRecipient(),
            address(principalRecipient),
            "invalid principal recipient"
        );

        assertEq(
            ObolCapsule(predictedAddress).rewardRecipient(),
            address(rewardRecipient),
            "invalid reward recipient"
        );

        assertEq(
            ObolCapsule(predictedAddress).recoveryAddress(),
            address(recoveryRecipient),
            "invalid recovery recipient"
        );
    }

    function testCannot_CreateWithInvalidPR() public {
        vm.expectRevert(
            Invalid__PrincipalRecipient.selector
        );
        obolCapsuleFactory.createCapsule(
            address(0),
            rewardRecipient,
            recoveryRecipient
        );
    }

    function testCannot_CreateWIthInvalidRR() public {
        vm.expectRevert(
            Invalid__RewardRecipient.selector
        );
        obolCapsuleFactory.createCapsule(
            principalRecipient,
            address(0),
            recoveryRecipient
        );
    }

    function testCannot_CreateWithInvalidRecoveryR() public {
        vm.expectRevert(
            Invalid__RecoveryRecipient.selector
        );
        obolCapsuleFactory.createCapsule(
            principalRecipient,
            rewardRecipient,
            address(0)
        );
    }

    function testFuzz_CreateCapsule(
        address fuzzPrincipalRecipient,
        address fuzzRewardRecipient,
        address fuzzRecoveryRecipient
    ) external {
        vm.assume(fuzzPrincipalRecipient != address(0));
        vm.assume(fuzzRewardRecipient != address(0));
        vm.assume(fuzzRecoveryRecipient != address(0));

        address predictedAddress = obolCapsuleFactory.predictCapsuleAddress(
            fuzzPrincipalRecipient,
            fuzzRewardRecipient,
            fuzzRecoveryRecipient
        );
        
        vm.expectEmit(false, false, false, true);
        emit CreateCapsule(predictedAddress, fuzzPrincipalRecipient, fuzzRewardRecipient, fuzzRecoveryRecipient);

        obolCapsuleFactory.createCapsule(
            fuzzPrincipalRecipient,
            fuzzRewardRecipient,
            fuzzRecoveryRecipient
        );

        assertEq(
            ObolCapsule(predictedAddress).principalRecipient(),
            address(fuzzPrincipalRecipient),
            "invalid principal recipient"
        );

        assertEq(
            ObolCapsule(predictedAddress).rewardRecipient(),
            address(fuzzRewardRecipient),
            "invalid reward recipient"
        );

        assertEq(
            ObolCapsule(predictedAddress).recoveryAddress(),
            address(fuzzRecoveryRecipient),
            "invalid recovery recipient"
        );
    }

}