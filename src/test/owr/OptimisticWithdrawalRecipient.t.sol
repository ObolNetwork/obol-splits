// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {OptimisticWithdrawalRecipient} from "src/owr/OptimisticWithdrawalRecipient.sol";
import {OptimisticWithdrawalRecipientFactory} from "src/owr/OptimisticWithdrawalRecipientFactory.sol";
import {MockERC20} from "../utils/mocks/MockERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {OWRReentrancy} from "./OWRReentrancy.sol";
import {OWRTestHelper} from "./OWRTestHelper.t.sol";
import {IENSReverseRegistrar} from "../../interfaces/external/IENSReverseRegistrar.sol";

contract OptimisticWithdrawalRecipientTest is OWRTestHelper, Test {
  using SafeTransferLib for address;

  event ReceiveETH(uint256 amount);
  event DistributeFunds(uint256 principalPayout, uint256 rewardPayout, uint256 pullFlowFlag);
  event RecoverNonOWRecipientFunds(address nonOWRToken, address recipient, uint256 amount);

  address public ENS_REVERSE_REGISTRAR_GOERLI = 0x084b1c3C81545d370f3634392De611CaaBFf8148;

  OptimisticWithdrawalRecipient public owrModule;
  OptimisticWithdrawalRecipientFactory public owrFactory;
  address internal recoveryAddress;

  OptimisticWithdrawalRecipient owrETH;
  OptimisticWithdrawalRecipient owrETH_OR;
  MockERC20 mERC20;

  address public principalRecipient;
  address public rewardRecipient;
  uint256 internal trancheThreshold;

  function setUp() public {
    vm.mockCall(
      ENS_REVERSE_REGISTRAR_GOERLI,
      abi.encodeWithSelector(IENSReverseRegistrar.setName.selector),
      bytes.concat(bytes32(0))
    );
    vm.mockCall(
      ENS_REVERSE_REGISTRAR_GOERLI,
      abi.encodeWithSelector(IENSReverseRegistrar.claim.selector),
      bytes.concat(bytes32(0))
    );

    owrFactory = new OptimisticWithdrawalRecipientFactory("demo.obol.eth", ENS_REVERSE_REGISTRAR_GOERLI, address(this));

    owrModule = owrFactory.owrImpl();

    mERC20 = new MockERC20("demo", "DMT", 18);
    mERC20.mint(type(uint256).max);

    (principalRecipient, rewardRecipient) = generateTrancheRecipients(uint256(uint160(makeAddr("tranche"))));
    // use 1 validator as default tranche threshold
    trancheThreshold = ETH_STAKE;

    recoveryAddress = makeAddr("recoveryAddress");

    owrETH = owrFactory.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, trancheThreshold);

    owrETH_OR = owrFactory.createOWRecipient(address(0), principalRecipient, rewardRecipient, trancheThreshold);
  }

  function testGetTranches() public {
    // eth
    (address _principalRecipient, address _rewardRecipient, uint256 wtrancheThreshold) = owrETH.getTranches();

    assertEq(_principalRecipient, principalRecipient, "invalid principal recipient");
    assertEq(_rewardRecipient, rewardRecipient, "invalid reward recipient");
    assertEq(wtrancheThreshold, ETH_STAKE, "invalid eth tranche threshold");
  }

  function testReceiveETH() public {
    address(owrETH).safeTransferETH(1 ether);
    assertEq(address(owrETH).balance, 1 ether);
  }

  function testReceiveTransfer() public {
    payable(address(owrETH)).transfer(1 ether);
    assertEq(address(owrETH).balance, 1 ether);
  }

  function testEmitOnReceiveETH() public {
    vm.expectEmit(true, true, true, true);
    emit ReceiveETH(1 ether);

    address(owrETH).safeTransferETH(1 ether);
  }

  function testReceiveERC20() public {
    address(mERC20).safeTransfer(address(owrETH), 1 ether);
    assertEq(mERC20.balanceOf(address(owrETH)), 1 ether);
  }

  function testCan_recoverNonOWRFundsToRecipient() public {
    address(owrETH).safeTransferETH(1 ether);
    address(mERC20).safeTransfer(address(owrETH), 1 ether);
    address(owrETH_OR).safeTransferETH(1 ether);
    address(mERC20).safeTransfer(address(owrETH_OR), 1 ether);

    vm.expectEmit(true, true, true, true);
    emit RecoverNonOWRecipientFunds(address(mERC20), recoveryAddress, 1 ether);
    owrETH.recoverFunds(address(mERC20), recoveryAddress);
    assertEq(address(owrETH).balance, 1 ether);
    assertEq(mERC20.balanceOf(address(owrETH)), 0 ether);
    assertEq(mERC20.balanceOf(recoveryAddress), 1 ether);

    vm.expectEmit(true, true, true, true);
    emit RecoverNonOWRecipientFunds(address(mERC20), principalRecipient, 1 ether);
    owrETH_OR.recoverFunds(address(mERC20), principalRecipient);
    assertEq(address(owrETH_OR).balance, 1 ether);
    assertEq(mERC20.balanceOf(address(owrETH_OR)), 0 ether);
    assertEq(mERC20.balanceOf(principalRecipient), 1 ether);

    address(mERC20).safeTransfer(address(owrETH_OR), 1 ether);

    vm.expectEmit(true, true, true, true);
    emit RecoverNonOWRecipientFunds(address(mERC20), rewardRecipient, 1 ether);
    owrETH_OR.recoverFunds(address(mERC20), rewardRecipient);
    assertEq(address(owrETH_OR).balance, 1 ether);
    assertEq(mERC20.balanceOf(address(owrETH_OR)), 0 ether);
    assertEq(mERC20.balanceOf(rewardRecipient), 1 ether);
  }

  function testCannot_recoverFundsToNonRecipient() public {
    vm.expectRevert(OptimisticWithdrawalRecipient.InvalidTokenRecovery_InvalidRecipient.selector);
    owrETH.recoverFunds(address(mERC20), address(1));

    vm.expectRevert(OptimisticWithdrawalRecipient.InvalidTokenRecovery_InvalidRecipient.selector);
    owrETH_OR.recoverFunds(address(mERC20), address(2));
  }

  function testCan_OWRIsPayable() public {
    owrETH.distributeFunds{value: 2 ether}();

    assertEq(address(owrETH).balance, 0 ether);
    assertEq(principalRecipient.balance, 0);
    assertEq(rewardRecipient.balance, 2 ether);
  }

  function testCan_distributeToNoRecipients() public {
    owrETH.distributeFunds();
    assertEq(principalRecipient.balance, 0 ether);
  }

  function testCan_emitOnDistributeToNoRecipients() public {
    uint256 principalPayout;
    uint256 rewardPayout;

    vm.expectEmit(true, true, true, true);
    emit DistributeFunds(principalPayout, rewardPayout, 0);
    owrETH.distributeFunds();
  }

  function testCan_distributeToSecondRecipient() public {
    address(owrETH).safeTransferETH(1 ether);

    uint256 rewardPayout = 1 ether;
    uint256 principalPayout;

    vm.expectEmit(true, true, true, true);
    emit DistributeFunds(principalPayout, rewardPayout, 0);
    owrETH.distributeFunds();
    assertEq(address(owrETH).balance, 0 ether);
    assertEq(rewardRecipient.balance, 1 ether);

    rewardPayout = 0;
    vm.expectEmit(true, true, true, true);
    emit DistributeFunds(principalPayout, rewardPayout, 0);
    owrETH.distributeFunds();
    assertEq(address(owrETH).balance, 0 ether);
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardRecipient.balance, 1 ether);
  }

  function testCan_distributeMultipleDepositsToRewardRecipient() public {
    address(owrETH).safeTransferETH(0.5 ether);
    owrETH.distributeFunds();
    assertEq(address(owrETH).balance, 0 ether);
    assertEq(rewardRecipient.balance, 0.5 ether);

    address(owrETH).safeTransferETH(0.5 ether);
    owrETH.distributeFunds();
    assertEq(address(owrETH).balance, 0 ether);
    assertEq(rewardRecipient.balance, 1 ether);
  }

  function testCan_distributeToBothRecipients() public {
    address(owrETH).safeTransferETH(36 ether);

    uint256 principalPayout = 32 ether;
    uint256 rewardPayout = 4 ether;

    vm.expectEmit(true, true, true, true);
    emit DistributeFunds(principalPayout, rewardPayout, 0);
    owrETH.distributeFunds();
    assertEq(address(owrETH).balance, 0 ether);
    assertEq(principalRecipient.balance, 32 ether);
    assertEq(rewardRecipient.balance, 4 ether);
  }

  function testCan_distributeMultipleDepositsToPrincipalRecipient() public {
    address(owrETH).safeTransferETH(16 ether);
    owrETH.distributeFunds();

    address(owrETH).safeTransferETH(16 ether);
    owrETH.distributeFunds();

    assertEq(address(owrETH).balance, 0 ether);
    assertEq(principalRecipient.balance, 32 ether);
    assertEq(rewardRecipient.balance, 0 ether);
  }

  function testCannot_distributeTooMuch() public {
    vm.deal(address(owrETH), type(uint128).max);
    owrETH.distributeFunds();
    vm.deal(address(owrETH), 1);

    vm.deal(address(owrETH), type(uint136).max);
    vm.expectRevert(OptimisticWithdrawalRecipient.InvalidDistribution_TooLarge.selector);
    owrETH.distributeFunds();

    vm.expectRevert(OptimisticWithdrawalRecipient.InvalidDistribution_TooLarge.selector);
    owrETH.distributeFundsPull();
  }

  function testCannot_reenterOWR() public {
    OWRReentrancy wr = new OWRReentrancy();

    owrETH = owrFactory.createOWRecipient(recoveryAddress, address(wr), rewardRecipient, 1 ether);
    address(owrETH).safeTransferETH(33 ether);

    vm.expectRevert(SafeTransferLib.ETHTransferFailed.selector);
    owrETH.distributeFunds();

    assertEq(address(owrETH).balance, 33 ether);
    assertEq(address(wr).balance, 0 ether);
    assertEq(address(0).balance, 0 ether);
  }

  function testCan_distributeToPullFlow() public {
    // test eth
    address(owrETH).safeTransferETH(36 ether);
    owrETH.distributeFundsPull();

    assertEq(address(owrETH).balance, 36 ether);
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardRecipient.balance, 0 ether);

    assertEq(owrETH.getPullBalance(principalRecipient), 32 ether);
    assertEq(owrETH.getPullBalance(rewardRecipient), 4 ether);

    assertEq(owrETH.fundsPendingWithdrawal(), 36 ether);

    owrETH.withdraw(rewardRecipient);

    assertEq(address(owrETH).balance, 32 ether);
    assertEq(principalRecipient.balance, 0);
    assertEq(rewardRecipient.balance, 4 ether);

    assertEq(owrETH.getPullBalance(principalRecipient), 32 ether);
    assertEq(owrETH.getPullBalance(rewardRecipient), 0);

    assertEq(owrETH.fundsPendingWithdrawal(), 32 ether);

    owrETH.withdraw(principalRecipient);

    assertEq(address(owrETH).balance, 0 ether);
    assertEq(principalRecipient.balance, 32 ether);
    assertEq(rewardRecipient.balance, 4 ether);

    assertEq(owrETH.getPullBalance(principalRecipient), 0);
    assertEq(owrETH.getPullBalance(rewardRecipient), 0);

    assertEq(owrETH.fundsPendingWithdrawal(), 0 ether);
  }

  function testCan_distributePushAndPull() public {
    // test eth
    address(owrETH).safeTransferETH(0.5 ether);
    assertEq(address(owrETH).balance, 0.5 ether, "2/incorrect balance");

    owrETH.distributeFunds();

    assertEq(address(owrETH).balance, 0, "3/incorrect balance");
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardRecipient.balance, 0.5 ether);

    assertEq(owrETH.getPullBalance(principalRecipient), 0 ether);
    assertEq(owrETH.getPullBalance(rewardRecipient), 0 ether);

    assertEq(owrETH.fundsPendingWithdrawal(), 0 ether);

    address(owrETH).safeTransferETH(1 ether);
    assertEq(address(owrETH).balance, 1 ether);

    owrETH.distributeFundsPull();

    assertEq(address(owrETH).balance, 1 ether);
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardRecipient.balance, 0.5 ether);

    assertEq(owrETH.getPullBalance(principalRecipient), 0 ether);
    assertEq(owrETH.getPullBalance(rewardRecipient), 1 ether);

    assertEq(owrETH.fundsPendingWithdrawal(), 1 ether);

    owrETH.distributeFunds();

    assertEq(address(owrETH).balance, 1 ether);
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardRecipient.balance, 0.5 ether);

    assertEq(owrETH.getPullBalance(principalRecipient), 0);
    assertEq(owrETH.getPullBalance(rewardRecipient), 1 ether);

    assertEq(owrETH.fundsPendingWithdrawal(), 1 ether);

    owrETH.distributeFundsPull();

    assertEq(address(owrETH).balance, 1 ether);
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardRecipient.balance, 0.5 ether);

    assertEq(owrETH.getPullBalance(principalRecipient), 0);
    assertEq(owrETH.getPullBalance(rewardRecipient), 1 ether);

    assertEq(owrETH.fundsPendingWithdrawal(), 1 ether);

    address(owrETH).safeTransferETH(1 ether);
    assertEq(address(owrETH).balance, 2 ether);

    owrETH.distributeFunds();

    assertEq(address(owrETH).balance, 1 ether);
    assertEq(principalRecipient.balance, 0);
    assertEq(rewardRecipient.balance, 1.5 ether);

    assertEq(owrETH.getPullBalance(principalRecipient), 0 ether);
    assertEq(owrETH.getPullBalance(rewardRecipient), 1 ether);

    assertEq(owrETH.fundsPendingWithdrawal(), 1 ether);

    owrETH.withdraw(rewardRecipient);

    assertEq(address(owrETH).balance, 0 ether);
    assertEq(principalRecipient.balance, 0);
    assertEq(rewardRecipient.balance, 2.5 ether);

    assertEq(owrETH.getPullBalance(principalRecipient), 0 ether);
    assertEq(owrETH.getPullBalance(rewardRecipient), 0 ether);

    assertEq(owrETH.fundsPendingWithdrawal(), 0);

    address(owrETH).safeTransferETH(1 ether);
    owrETH.withdraw(rewardRecipient);

    assertEq(address(owrETH).balance, 1 ether);
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardRecipient.balance, 2.5 ether);

    assertEq(owrETH.getPullBalance(principalRecipient), 0 ether);
    assertEq(owrETH.getPullBalance(rewardRecipient), 0 ether);

    assertEq(owrETH.fundsPendingWithdrawal(), 0 ether);
  }

  function testFuzzCan_distributeDepositsToRecipients(
    uint256 _recipientsSeed,
    uint256 _thresholdsSeed,
    uint8 _numDeposits,
    uint256 _ethAmount,
    uint256 _erc20Amount
  ) public {
    _ethAmount = uint256(bound(_ethAmount, 0.01 ether, 34 ether));
    _erc20Amount = uint256(bound(_erc20Amount, 0.01 ether, 34 ether));
    vm.assume(_numDeposits > 0);
    (address _principalRecipient, address _rewardRecipient, uint256 _trancheThreshold) =
      generateTranches(_recipientsSeed, _thresholdsSeed);

    owrETH = owrFactory.createOWRecipient(recoveryAddress, _principalRecipient, _rewardRecipient, _trancheThreshold);

    /// test eth
    for (uint256 i = 0; i < _numDeposits; i++) {
      address(owrETH).safeTransferETH(_ethAmount);
    }
    owrETH.distributeFunds();

    uint256 _totalETHAmount = uint256(_numDeposits) * uint256(_ethAmount);

    assertEq(address(owrETH).balance, 0 ether, "invalid balance");
    // assertEq(owrETH.distributedFunds(), _totalETHAmount, "undistributed funds");
    assertEq(owrETH.fundsPendingWithdrawal(), 0 ether, "funds pending withdraw");

    if (BALANCE_CLASSIFICATION_THRESHOLD > _totalETHAmount) {
      // then all of the deposit should be classified as reward
      assertEq(_principalRecipient.balance, 0, "should not classify reward as principal");

      assertEq(_rewardRecipient.balance, _totalETHAmount, "invalid amount");
    }

    if (_ethAmount > BALANCE_CLASSIFICATION_THRESHOLD) {
      // then all of reward classified as principal
      // but check if _totalETHAmount > first threshold
      if (_totalETHAmount > _trancheThreshold) {
        // there is reward
        assertEq(_principalRecipient.balance, _trancheThreshold, "invalid amount");

        assertEq(
          _rewardRecipient.balance, _totalETHAmount - _trancheThreshold, "should not classify principal as reward"
        );
      } else {
        // eelse no rewards
        assertEq(_principalRecipient.balance, _totalETHAmount, "invalid amount");

        assertEq(_rewardRecipient.balance, 0, "should not classify principal as reward");
      }
    }
  }

  function testFuzzCan_distributePullDepositsToRecipients(
    uint256 _recipientsSeed,
    uint256 _thresholdsSeed,
    uint8 _numDeposits,
    uint256 _ethAmount,
    uint256 _erc20Amount
  ) public {
    _ethAmount = uint256(bound(_ethAmount, 0.01 ether, 40 ether));
    _erc20Amount = uint256(bound(_erc20Amount, 0.01 ether, 40 ether));
    vm.assume(_numDeposits > 0);

    (address _principalRecipient, address _rewardRecipient, uint256 _trancheThreshold) =
      generateTranches(_recipientsSeed, _thresholdsSeed);

    owrETH = owrFactory.createOWRecipient(recoveryAddress, _principalRecipient, _rewardRecipient, _trancheThreshold);

    /// test eth

    for (uint256 i = 0; i < _numDeposits; i++) {
      address(owrETH).safeTransferETH(_ethAmount);
      owrETH.distributeFundsPull();
    }
    uint256 _totalETHAmount = uint256(_numDeposits) * uint256(_ethAmount);

    assertEq(address(owrETH).balance, _totalETHAmount);
    // assertEq(owrETH.distributedFunds(), _totalETHAmount);
    assertEq(owrETH.fundsPendingWithdrawal(), _totalETHAmount);

    uint256 principal = owrETH.getPullBalance(_principalRecipient);
    assertEq(
      owrETH.getPullBalance(_principalRecipient),
      (_ethAmount >= BALANCE_CLASSIFICATION_THRESHOLD)
        ? _trancheThreshold > _totalETHAmount ? _totalETHAmount : _trancheThreshold
        : 0,
      "5/invalid recipient balance"
    );

    uint256 reward = owrETH.getPullBalance(_rewardRecipient);
    assertEq(
      owrETH.getPullBalance(_rewardRecipient),
      (_ethAmount >= BALANCE_CLASSIFICATION_THRESHOLD)
        ? _totalETHAmount > _trancheThreshold ? (_totalETHAmount - _trancheThreshold) : 0
        : _totalETHAmount,
      "6/invalid recipient balance"
    );

    owrETH.withdraw(_principalRecipient);
    owrETH.withdraw(_rewardRecipient);

    assertEq(address(owrETH).balance, 0);
    assertEq(owrETH.fundsPendingWithdrawal(), 0);

    assertEq(_principalRecipient.balance, principal, "10/invalid principal balance");
    assertEq(_rewardRecipient.balance, reward, "11/invalid reward balance");
  }
}
