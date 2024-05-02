// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import { ObolCapsule, ObolCapsuleFactory } from "src/capsule/ObolCapsuleFactory.sol";

contract ObolCapsuleFactoryTest is Test {

    address constant ETH2_DEPOSIT_CONTRACT = 0x1;

    ObolCapsuleFactory public obolCapsuleFactory;
    ObolCapsule public createdObolCapsule;

    uint256 feeShare;
    address feeRecipient;
    address owner;

    function setUp() public {
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
    }

    function test_CreateCapsule() external {

    }

    function test_GetVerifier() external {

    }

    function test_CannotSetVerifierIfNotOwner() external {

    }

    function test_SetVerifier() external {

    }


}