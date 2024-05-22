// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {OptimisticTokenWithdrawalRecipient} from "src/owr/token/OptimisticTokenWithdrawalRecipient.sol";
import {OptimisticTokenWithdrawalRecipientFactory} from "src/owr/token/OptimisticTokenWithdrawalRecipientFactory.sol";
import {MockERC20} from "../../../utils/mocks/MockERC20.sol";
import {OWRTestHelper} from "../../OWRTestHelper.t.sol";

contract GNOOWTRIntegration is OWRTestHelper, Test {
    OptimisticTokenWithdrawalRecipientFactory owrFactoryModule;
    MockERC20 mERC20;
    address public recoveryAddress;
    address public principalRecipient;
    address public rewardRecipient;
    uint256 public threshold;

    uint256 internal constant GNO_BALANCE_CLASSIFICATOION_THRESHOLD = 0.8 ether;

    function setUp() public {
        mERC20 = new MockERC20("Test Token", "TOK", 18);
        mERC20.mint(type(uint256).max);

        owrFactoryModule = new OptimisticTokenWithdrawalRecipientFactory(GNO_BALANCE_CLASSIFICATOION_THRESHOLD);

        recoveryAddress = makeAddr("recoveryAddress");
        (principalRecipient, rewardRecipient) = generateTrancheRecipients(10);
        threshold = 10 ether;
    }

    function test_Distribute() public {
        OptimisticTokenWithdrawalRecipient gnoRecipient = owrFactoryModule.createOWRecipient(
            ETH_ADDRESS,
            recoveryAddress,
            principalRecipient,
            rewardRecipient,
            threshold
        );

        uint256 amountToStake = 0.001 ether;
        for (uint256 i = 0; i < 5; i++) {
            payable(address(gnoRecipient)).transfer(amountToStake);
        }
        
        gnoRecipient.distributeFunds();

        // ensure it goes to the rewardRecipient
        assertEq(
            address (rewardRecipient).balance,
            amountToStake * 5,
            "failed to stake"
        );

        // ensure it goes to principal recipient
        uint256 amountPrincipal = 2 ether;

        payable(address(gnoRecipient)).transfer(amountPrincipal);
        gnoRecipient.distributeFunds();

        // ensure it goes to the principal recipient
        assertEq(
            address(principalRecipient).balance,
            amountPrincipal,
            "failed to stake"
        );

        assertEq(
            gnoRecipient.claimedPrincipalFunds(),
            amountPrincipal,
            "invalid claimed principal funds"
        );

        uint256 prevRewardBalance = address(rewardRecipient).balance;

        for (uint i = 0; i < 5; i++) {
            payable(address(gnoRecipient)).transfer(amountPrincipal);
        }
        
        gnoRecipient.distributeFunds();

        // ensure it goes to the principal recipient
        assertEq(
            address(principalRecipient).balance,
            threshold,
            "principal recipient balance valid"
        );

        assertEq(
           gnoRecipient.claimedPrincipalFunds(),
            threshold,
            "claimed funds not equal threshold"
        );

        assertEq(
            address (rewardRecipient).balance,
            prevRewardBalance + amountPrincipal,
            "reward recipient should recieve remaining funds"
        );
    }
}