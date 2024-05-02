// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import { ObolCapsule, ObolCapsuleFactory } from "src/capsule/ObolCapsuleFactory.sol";

contract ObolCapsuleTest is Test {

    address constant ETH2_DEPOSIT_CONTRACT = 0x1;

    ObolCapsuleFactory public obolCapsuleFactory;
    ObolCapsule public createdObolCapsule;

    uint256 feeShare;
    address feeRecipient;
    address owner;
    address rewardRecipient;
    address principalRecipient;


    function setup() public {
        feeRecipient =  makeAddr("feeRecipient");
        rewardRecipient = makeAddr("rewardRecipient");
        principalRecipient = makeAddr("principalRecipient");

        owner = makeAddr("owner");
        feeShare = 10_000;
        
        obolCapsuleFactory = new ObolCapsuleFactory(
            ETH2_DEPOSIT_CONTRACT,
            owner,
            feeRecipient,
            feeShare
        );

        createdObolCapsule = obolCapsuleFactory.createCapsule(
            rewardRecipient,
            principalRecipient
        );
    }

    function test_Stake() external {

    }

    function testFuzz_Stake() external {

    }

    function testCannot_StakeWithInvalidConfig() public {

    }

    function testCannot_StakeWithInvalidStakeSize() public {

    }
}