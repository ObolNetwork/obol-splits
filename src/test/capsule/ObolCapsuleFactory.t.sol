// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {IETHPOSDeposit} from "src/interfaces/IETHPOSDeposit.sol";
import { ETHPOSDepositMock } from "../utils/mocks/ETHDepositMock.sol";
import { ObolCapsule, ObolCapsuleFactory } from "src/capsule/ObolCapsuleFactory.sol";

// contract ObolCapsuleFactoryTest is Test {

//     ObolCapsuleFactory public obolCapsuleFactory;
//     ObolCapsule public createdObolCapsule;

//     error Unauthorized();
//     error Invalid__Address();
//     error Invalid__RewardRecipient();
//     error Invalid__PrincipalRecipient();
//     error Invalid__RecoveryRecipient();


//     event CreateCapsule(
//         address indexed capsule,
//         address principalRecipient,
//         address rewardRecipient,
//         address recoveryRecipient
//     );
//     event UpdateStateProofVerifier(
//         address indexed oldVerifier,
//         address newVerifier
//     );

//     uint256 feeShare;
//     address rewardRecipient;
//     address principalRecipient;
//     address recoveryRecipient;
//     address feeRecipient;
//     address owner;

//     ETHPOSDepositMock ethPOSDepositMock;

//     function setUp() public {

//         ethPOSDepositMock = new ETHPOSDepositMock();

//         feeRecipient =  makeAddr("feeRecipient");
//         rewardRecipient = makeAddr("rewardRecipient");
//         principalRecipient = makeAddr("principalRecipient");
//         recoveryRecipient = makeAddr("recoveryRecipient");

//         owner = makeAddr("owner");
//         feeShare = 10_000;
        
//         obolCapsuleFactory = new ObolCapsuleFactory(
//             address(ethPOSDepositMock),
//             owner,
//             feeRecipient,
//             feeShare
//         );
//     }

//     function test_CreateCapsule() external {
//         address predictedAddress = obolCapsuleFactory.predictCapsuleAddress(
//             principalRecipient,
//             rewardRecipient,
//             recoveryRecipient
//         );

//         vm.expectEmit(false, false, false, true);
//         emit CreateCapsule(predictedAddress, principalRecipient, rewardRecipient, recoveryRecipient);

//         obolCapsuleFactory.createCapsule(
//             principalRecipient,
//             rewardRecipient,
//             recoveryRecipient
//         );
//     }

//     function testCannot_CreateWithInvalidPR() public {
//         vm.expectRevert(
//             Invalid__PrincipalRecipient.selector
//         );
//         obolCapsuleFactory.createCapsule(
//             address(0),
//             rewardRecipient,
//             recoveryRecipient
//         );
//     }

//     function testCannot_CreateWIthInvalidRR() public {
//         vm.expectRevert(
//             Invalid__RewardRecipient.selector
//         );
//         obolCapsuleFactory.createCapsule(
//             principalRecipient,
//             address(0),
//             recoveryRecipient
//         );
//     }

//     function testCannot_CreateWithInvalidRecoveryR() public {
//         vm.expectRevert(
//             Invalid__RecoveryRecipient.selector
//         );
//         obolCapsuleFactory.createCapsule(
//             principalRecipient,
//             rewardRecipient,
//             address(0)
//         );
//     }

//     function test_Owner() public {
//         assertEq(
//             obolCapsuleFactory.owner(),
//             owner,
//             "invalid owner"
//         );
//     }

//     function testFuzz_CreateCapsule(
//         address fuzzPrincipalRecipient,
//         address fuzzRewardRecipient,
//         address fuzzRecoveryRecipient
//     ) external {
//         vm.assume(fuzzPrincipalRecipient != address(0));
//         vm.assume(fuzzRewardRecipient != address(0));
//         vm.assume(fuzzRecoveryRecipient != address(0));

//         address predictedAddress = obolCapsuleFactory.predictCapsuleAddress(
//             fuzzPrincipalRecipient,
//             fuzzRewardRecipient,
//             fuzzRecoveryRecipient
//         );
        
//         vm.expectEmit(false, false, false, true);
//         emit CreateCapsule(predictedAddress, fuzzPrincipalRecipient, fuzzRewardRecipient, fuzzRecoveryRecipient);

//         obolCapsuleFactory.createCapsule(
//             fuzzPrincipalRecipient,
//             fuzzRewardRecipient,
//             fuzzRecoveryRecipient
//         );
//     }

//     function test_GetVerifier() external {
//         assertTrue(
//             address(obolCapsuleFactory.getVerifier()) != address(0),
//             "Failed to set verifier"
//         );
//     }

//     function testCannot_SetVerifierIfNotOwner() external {
//         address newVerifier = makeAddr("newVerifier");

//         vm.expectRevert(
//             Unauthorized.selector
//         );
//         obolCapsuleFactory.setNewVerifier(newVerifier);
//     }

//     function testCannot_SetVerifierAddressZero() external {
//         vm.prank(owner);
//         vm.expectRevert(
//             Invalid__Address.selector
//         );
//         obolCapsuleFactory.setNewVerifier(address(0));
//     }

//     function test_SetVerifier() external {
//         address newVerifier = makeAddr("newVerifier");

//         vm.expectEmit(true, true, true, true);
//         emit UpdateStateProofVerifier(
//             address(obolCapsuleFactory.getVerifier()),
//             newVerifier
//         );

//         vm.prank(owner);
//         obolCapsuleFactory.setNewVerifier(newVerifier);
//     }

// }