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

  uint256 internal constant GNO_BALANCE_CLASSIFICATION_THRESHOLD = 0.8 ether;

  function setUp() public {
    mERC20 = new MockERC20("demo", "DMT", 18);
    mERC20.mint(type(uint256).max);

    owrFactoryModule = new OptimisticTokenWithdrawalRecipientFactory(GNO_BALANCE_CLASSIFICATION_THRESHOLD);

    recoveryAddress = makeAddr("recoveryAddress");
    (principalRecipient, rewardRecipient) = generateTrancheRecipients(10);
    threshold = 10 ether;
  }

  function test_Distribute() public {
    OptimisticTokenWithdrawalRecipient gnoRecipient = owrFactoryModule.createOWRecipient(
      address(mERC20), recoveryAddress, principalRecipient, rewardRecipient, threshold
    );

    uint256 amountToStake = 0.001 ether;
    for (uint256 i = 0; i < 5; i++) {
      mERC20.transfer(address(gnoRecipient), amountToStake);
    }

    gnoRecipient.distributeFunds();

    // ensure it goes to the rewardRecipient
    assertEq(mERC20.balanceOf(rewardRecipient), amountToStake * 5, "failed to stake");

    // ensure it goes to principal recipient
    uint256 amountPrincipal = 2 ether;

    mERC20.transfer(address(gnoRecipient), amountPrincipal);
    gnoRecipient.distributeFunds();

    // ensure it goes to the principal recipient
    assertEq(mERC20.balanceOf(principalRecipient), amountPrincipal, "failed to stake");

    assertEq(gnoRecipient.claimedPrincipalFunds(), amountPrincipal, "invalid claimed principal funds");

    uint256 prevRewardBalance = mERC20.balanceOf(rewardRecipient);

    for (uint256 i = 0; i < 5; i++) {
      mERC20.transfer(address(gnoRecipient), amountPrincipal);
    }

    gnoRecipient.distributeFunds();

    // ensure it goes to the principal recipient
    assertEq(mERC20.balanceOf(principalRecipient), threshold, "principal recipient balance valid");

    assertEq(gnoRecipient.claimedPrincipalFunds(), threshold, "claimed funds not equal threshold");

    assertEq(
      mERC20.balanceOf(rewardRecipient),
      prevRewardBalance + amountPrincipal,
      "reward recipient should recieve remaining funds"
    );
  }

  function testFuzz_Distribute(
    uint256 amountToDistribute,
    address fuzzPrincipalRecipient,
    address fuzzRewardRecipient,
    uint256 fuzzThreshold
  ) public {
    vm.assume(fuzzRewardRecipient != address(0));
    vm.assume(fuzzPrincipalRecipient != address(0));
    vm.assume(fuzzRewardRecipient != fuzzPrincipalRecipient);
    vm.assume(amountToDistribute > 0);
    fuzzThreshold = bound(fuzzThreshold, 1, type(uint96).max);

    OptimisticTokenWithdrawalRecipient gnoRecipient = owrFactoryModule.createOWRecipient(
      address(mERC20), recoveryAddress, fuzzPrincipalRecipient, fuzzRewardRecipient, fuzzThreshold
    );

    uint256 amountToShare = bound(amountToDistribute, 1e18, type(uint96).max);

    mERC20.transfer(address(gnoRecipient), amountToShare);

    gnoRecipient.distributeFunds();

    if (amountToShare >= GNO_BALANCE_CLASSIFICATION_THRESHOLD) {
      if (amountToShare > fuzzThreshold) {
        assertEq(mERC20.balanceOf(fuzzPrincipalRecipient), fuzzThreshold, "invalid principal balance 1");
        assertEq(gnoRecipient.claimedPrincipalFunds(), fuzzThreshold, "invalid claimed principal funds 2");
        assertEq(mERC20.balanceOf(fuzzRewardRecipient), amountToShare - fuzzThreshold, "invalid reward balance 3");
      } else {
        assertEq(mERC20.balanceOf(fuzzPrincipalRecipient), amountToShare, "invalid principal balance 4");
        assertEq(gnoRecipient.claimedPrincipalFunds(), amountToShare, "invalid claimed principal funds 5");
        assertEq(mERC20.balanceOf(fuzzRewardRecipient), 0, "invalid reward balance 6");
      }
    } else {
      assertEq(mERC20.balanceOf(fuzzPrincipalRecipient), 0, "invalid principal balance 7");
      assertEq(gnoRecipient.claimedPrincipalFunds(), 0, "invalid claimed principal funds 8");
      assertEq(mERC20.balanceOf(fuzzRewardRecipient), amountToShare, "invalid reward balance 9");
    }
  }
}
