// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {IETHPOSDeposit} from "src/interfaces/IETHPOSDeposit.sol";
import {IProofVerifier} from "src/interfaces/IProofVerifier.sol";
import { ETHPOSDepositMock } from "../utils/mocks/ETHDepositMock.sol";
import { ObolCapsule, ObolCapsuleFactory } from "src/capsule/ObolCapsuleFactory.sol";

contract ObolCapsuleTest is Test {

    // address constant ETH2_DEPOSIT_CONTRACT_MAINNET = 0x00000000219ab540356cBB839Cbe05303d7705Fa;

    // event ObolPodStaked(bytes32 pubkeyHash, uint256 amount);


    // ObolCapsuleFactory public obolCapsuleFactory;
    // ObolCapsule public createdObolCapsule;

    // uint256 feeShare;
    // address feeRecipient;
    // address owner;
    // address rewardRecipient;
    // address principalRecipient;
    // address recoveryRecipient;

    // bytes pubkey;
    // bytes signature;
    // bytes32 depositDataRoot;

    // ETHPOSDepositMock ethPOSDepositMock;

    // function setUp() public {
    //     pubkey = bytes("demo");

    //     ethPOSDepositMock = new ETHPOSDepositMock();

    //     feeRecipient =  makeAddr("feeRecipient");
    //     recoveryRecipient = makeAddr("recoveryRecipient");
    //     rewardRecipient = makeAddr("rewardRecipient");
    //     principalRecipient = makeAddr("principalRecipient");

    //     owner = makeAddr("owner");
    //     feeShare = 10_000;
        
    //     obolCapsuleFactory = new ObolCapsuleFactory(
    //         address(ethPOSDepositMock),
    //         owner,
    //         feeRecipient,
    //         feeShare
    //     );

    //     createdObolCapsule = ObolCapsule(obolCapsuleFactory.createCapsule(
    //         principalRecipient,
    //         rewardRecipient,
    //         recoveryRecipient
    //     ));
    // }

    // function test_RewardRecipient() external {
    //     assertEq(
    //         createdObolCapsule.rewardRecipient(),
    //         rewardRecipient,
    //         "invalid reward recipient"
    //     );
    // }

    // function test_PrincipalRecipient() external {
    //     assertEq(
    //         createdObolCapsule.principalRecipient(),
    //         principalRecipient,
    //         "invalid principal recipient"
    //     );
    // }

    // function test_RecoveryAddress() external {
    //     assertEq(
    //         createdObolCapsule.recoveryAddress(),
    //         recoveryRecipient,
    //         "invalid recovery recipient"
    //     );
    // }

    // function test_Stake() external {
    //     bytes32 pubkeyHash = keccak256(pubkey);

    //     uint256 amountToStake = 10 ether;
        
    //     vm.expectEmit(true, true, true, true);
    //     emit ObolPodStaked(pubkeyHash, amountToStake);

    //     createdObolCapsule.stake{value: amountToStake}(
    //         pubkey,
    //         signature,
    //         depositDataRoot
    //     );

    //     assertEq(
    //         address(ethPOSDepositMock).balance,
    //         amountToStake,
    //         "invalid balance"
    //     );

    //     IProofVerifier.VALIDATOR_STATUS status;
    //     (, status) = createdObolCapsule.validators(pubkeyHash);
        
    //     assertEq(
    //         uint8(status),
    //         uint8(IProofVerifier.VALIDATOR_STATUS.ACTIVE),
    //         "invalid validator status"
    //     );
    // }

    // function testFuzz_DoubleStake(uint8 quantity, uint256 amountToStake) external {
    //     vm.assume(quantity > 0);

    //     bytes32 pubkeyHash = keccak256(pubkey);
        
    //     amountToStake = bound(amountToStake, 10, type(uint96).max);

    //     for (uint i = 0; i < quantity; i++) {
    //         vm.deal(address(this), amountToStake);
            
    //         vm.expectEmit(true, true, true, true);
    //         emit ObolPodStaked(pubkeyHash, amountToStake);

    //         createdObolCapsule.stake{value: amountToStake}(
    //             pubkey,
    //             signature,
    //             depositDataRoot
    //         );

    //         IProofVerifier.VALIDATOR_STATUS checkStatus;
    //         (, checkStatus) = createdObolCapsule.validators(pubkeyHash);

    //         assertEq(
    //             uint8(checkStatus),
    //             uint8(IProofVerifier.VALIDATOR_STATUS.ACTIVE),
    //             "invalid validator status"
    //         );
    //     }

    //     IProofVerifier.VALIDATOR_STATUS status;
    //     (, status) = createdObolCapsule.validators(pubkeyHash);

    //     assertEq(
    //         uint8(status),
    //         uint8(IProofVerifier.VALIDATOR_STATUS.ACTIVE),
    //         "invalid validator status"
    //     );
    // }

    // function testFuzz_Stake(bytes memory fuzzPubkey, address user, uint256 amountToStake) external {
    //     bytes32 pubkeyHash = keccak256(fuzzPubkey);

    //     amountToStake = bound(amountToStake, 10, type(uint96).max);

    //     vm.deal(user, amountToStake);

    //     vm.expectEmit(true, true, true, true);
    //     emit ObolPodStaked(pubkeyHash, amountToStake);

    //     createdObolCapsule.stake{value: amountToStake}(
    //         fuzzPubkey,
    //         signature,
    //         depositDataRoot
    //     );

    //     IProofVerifier.VALIDATOR_STATUS status;
    //     (, status) = createdObolCapsule.validators(pubkeyHash);

    //     assertEq(
    //         uint8(status),
    //         uint8(IProofVerifier.VALIDATOR_STATUS.ACTIVE),
    //         "invalid validator status"
    //     );
    // }

}