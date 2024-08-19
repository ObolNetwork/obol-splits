// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ObolRocketPoolRecipientFactory} from "src/rocket-pool/ObolRocketPoolRecipientFactory.sol";
import {ObolRocketPoolRecipient} from "src/rocket-pool/ObolRocketPoolRecipient.sol";
import {RocketPoolTestHelper} from "./RocketPoolTestHelper.t.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {MockERC20} from "../utils/mocks/MockERC20.sol";
import {IENSReverseRegistrar} from "../../interfaces/IENSReverseRegistrar.sol";

import {RPMinipoolManagerMock} from "./mocks/RPMinipoolManagerMock.sol";
import {RPMinipoolMock} from "./mocks/RPMinipoolMock.sol";
import {RPStorageMock} from "./mocks/RPStorageMock.sol";

contract ObolRocketPoolRecipientTest is RocketPoolTestHelper, Test {
  using SafeTransferLib for address;

  event DistributeFunds(uint256 principalPayout, uint256 rewardPayout, uint256 pullFlowFlag);
  event RecoverFunds(address token, address recipient, uint256 amount);
  event ReceiveETH(uint256 amount);

  address public ENS_REVERSE_REGISTRAR_GOERLI = 0x084b1c3C81545d370f3634392De611CaaBFf8148;

  ObolRocketPoolRecipient public rpModule;
  ObolRocketPoolRecipientFactory public rpFactory;
  RPStorageMock rpStorage;
  address internal recoveryAddress;

  ObolRocketPoolRecipient public rpRecipient;
  MockERC20 mERC20;
  RPMinipoolMock minipool;
  RPMinipoolManagerMock minipoolManager;

  address public principalRecipient;
  address public rewardRecipient;
  uint256 internal trancheThreshold;

  function setUp() public {
    mERC20 = new MockERC20("demo", "DMT", 18);
    mERC20.mint(type(uint256).max);

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

    rpStorage = new RPStorageMock();
    rpFactory = new ObolRocketPoolRecipientFactory(
      address(rpStorage), "demo.obol.eth", ENS_REVERSE_REGISTRAR_GOERLI, address(this)
    );

    rpModule = rpFactory.rpRecipientImplementation();

    (principalRecipient, rewardRecipient) = generateTrancheRecipients(uint256(uint160(makeAddr("tranche"))));
    // use 1 validator as default tranche threshold
    trancheThreshold = ETH_STAKE;

    recoveryAddress = makeAddr("recoveryAddress");

    rpRecipient =
      rpFactory.createObolRocketPoolRecipient(recoveryAddress, principalRecipient, rewardRecipient, trancheThreshold);

    minipool = new RPMinipoolMock();
    minipoolManager = new RPMinipoolManagerMock();
    rpStorage.setMinipoolManager(address(minipoolManager));
  }

  function testGetTranches_rp() public {
    (address _principalRecipient, address _rewardRecipient, uint256 wtrancheThreshold) = rpRecipient.getTranches();

    assertEq(_principalRecipient, principalRecipient, "invalid principal recipient");
    assertEq(_rewardRecipient, rewardRecipient, "invalid reward recipient");
    assertEq(wtrancheThreshold, ETH_STAKE, "invalid eth tranche threshold");
  }

  function testReceiveETH_rp() public {
    address(rpRecipient).safeTransferETH(1 ether);
    assertEq(address(rpRecipient).balance, 1 ether);
  }

  function testReceiveTransfer_rp() public {
    payable(address(rpRecipient)).transfer(1 ether);
    assertEq(address(rpRecipient).balance, 1 ether);
  }

  function testEmitOnReceiveETH_rp() public {
    vm.expectEmit(true, true, true, true);
    emit ReceiveETH(1 ether);

    address(rpRecipient).safeTransferETH(1 ether);
  }

  function testCan_recoverNonRocketPoolRecipientFundsToRecipient() public {
    address(rpRecipient).safeTransferETH(1 ether);
    address(mERC20).safeTransfer(address(rpRecipient), 1 ether);

    vm.expectEmit(true, true, true, true);
    emit RecoverFunds(address(mERC20), recoveryAddress, 1 ether);
    rpRecipient.recoverFunds(address(mERC20), recoveryAddress);
    assertEq(address(rpRecipient).balance, 1 ether);
    assertEq(mERC20.balanceOf(address(rpRecipient)), 0 ether);
    assertEq(mERC20.balanceOf(recoveryAddress), 1 ether);
  }

  function testCannot_recoverRocketPoolRecipientFundsToNonRecipient() public {
    vm.expectRevert(ObolRocketPoolRecipient.InvalidTokenRecovery_InvalidRecipient.selector);
    rpRecipient.recoverFunds(address(mERC20), address(1));
  }

  function testCan_RocketPoolRecipientIsPayable() public {
    address(minipool).safeTransferETH(2 ether);
    rpRecipient.distributeFunds(address(minipool), true);

    assertEq(address(rpRecipient).balance, 0 ether);
    assertEq(principalRecipient.balance, 0);
    assertEq(rewardRecipient.balance, 2 ether);
  }

  function testCan_distributeToRocketPoolNoRecipients() public {
    rpRecipient.distributeFunds(address(minipool), true);
    assertEq(principalRecipient.balance, 0 ether);
  }

  function testCan_emitOnDistributeToRocketPoolNoRecipients() public {
    uint256 principalPayout;
    uint256 rewardPayout;

    vm.expectEmit(true, true, true, true);
    emit DistributeFunds(principalPayout, rewardPayout, 0);
    rpRecipient.distributeFunds(address(minipool), true);
  }

  function testCan_distributeMultipleMinipoolDepositsToRewardRecipient() public {
    address(minipool).safeTransferETH(0.5 ether);
    rpRecipient.distributeFunds(address(minipool), true);
    assertEq(address(rpRecipient).balance, 0 ether);
    assertEq(rewardRecipient.balance, 0.5 ether);

    address(minipool).safeTransferETH(0.5 ether);
    rpRecipient.distributeFunds(address(minipool), true);
    assertEq(address(rpRecipient).balance, 0 ether);
    assertEq(rewardRecipient.balance, 1 ether);
  }

  function testCan_distributeToBothRocketPoolRecipients() public {
    address(minipool).safeTransferETH(18 ether);

    uint256 principalPayout = 16 ether;
    uint256 rewardPayout = 2 ether;

    vm.expectEmit(true, true, true, true);
    emit DistributeFunds(principalPayout, rewardPayout, 0);
    rpRecipient.distributeFunds(address(minipool), true);
    assertEq(address(rpRecipient).balance, 0 ether);
    assertEq(principalRecipient.balance, 16 ether);
    assertEq(rewardRecipient.balance, 2 ether);
  }

  function testCan_distributeMultipleMinipoolDepositsToPrincipalRecipient() public {
    address(minipool).safeTransferETH(8 ether);
    rpRecipient.distributeFunds(address(minipool), true);

    address(minipool).safeTransferETH(8 ether);
    rpRecipient.distributeFunds(address(minipool), true);

    assertEq(address(rpRecipient).balance, 0 ether);
    assertEq(principalRecipient.balance, 16 ether);
    assertEq(rewardRecipient.balance, 0 ether);
  }

  function testCan_distributeToPullFlowForRocketPoolRecipient() public {
    address(minipool).safeTransferETH(20 ether);
    rpRecipient.distributeFundsPull(address(minipool), true);

    assertEq(address(rpRecipient).balance, 20 ether);
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardRecipient.balance, 0 ether);

    assertEq(rpRecipient.getPullBalance(principalRecipient), 16 ether);
    assertEq(rpRecipient.getPullBalance(rewardRecipient), 4 ether);

    assertEq(rpRecipient.fundsPendingWithdrawal(), 20 ether);

    rpRecipient.withdraw(rewardRecipient);

    assertEq(address(rpRecipient).balance, 16 ether);
    assertEq(principalRecipient.balance, 0);
    assertEq(rewardRecipient.balance, 4 ether);

    assertEq(rpRecipient.getPullBalance(principalRecipient), 16 ether);
    assertEq(rpRecipient.getPullBalance(rewardRecipient), 0);

    assertEq(rpRecipient.fundsPendingWithdrawal(), 16 ether);

    rpRecipient.withdraw(principalRecipient);

    assertEq(address(rpRecipient).balance, 0 ether);
    assertEq(principalRecipient.balance, 16 ether);
    assertEq(rewardRecipient.balance, 4 ether);

    assertEq(rpRecipient.getPullBalance(principalRecipient), 0);
    assertEq(rpRecipient.getPullBalance(rewardRecipient), 0);

    assertEq(rpRecipient.fundsPendingWithdrawal(), 0 ether);
  }

  function testCan_distributePushAndPullToRocketPoolRecipients() public {
    address(minipool).safeTransferETH(0.5 ether);
    assertEq(address(minipool).balance, 0.5 ether, "2/incorrect balance");

    rpRecipient.distributeFunds(address(minipool), true);

    assertEq(address(rpRecipient).balance, 0, "3/incorrect balance");
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardRecipient.balance, 0.5 ether);

    assertEq(rpRecipient.getPullBalance(principalRecipient), 0 ether);
    assertEq(rpRecipient.getPullBalance(rewardRecipient), 0 ether);

    assertEq(rpRecipient.fundsPendingWithdrawal(), 0 ether);

    address(minipool).safeTransferETH(1 ether);
    assertEq(address(minipool).balance, 1 ether);

    rpRecipient.distributeFundsPull(address(minipool), true);

    assertEq(address(rpRecipient).balance, 1 ether);
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardRecipient.balance, 0.5 ether);

    assertEq(rpRecipient.getPullBalance(principalRecipient), 0 ether);
    assertEq(rpRecipient.getPullBalance(rewardRecipient), 1 ether);

    assertEq(rpRecipient.fundsPendingWithdrawal(), 1 ether);

    rpRecipient.distributeFunds(address(minipool), true);
    assertEq(address(rpRecipient).balance, 1 ether);
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardRecipient.balance, 0.5 ether);

    assertEq(rpRecipient.getPullBalance(principalRecipient), 0);
    assertEq(rpRecipient.getPullBalance(rewardRecipient), 1 ether);

    assertEq(rpRecipient.fundsPendingWithdrawal(), 1 ether);

    rpRecipient.distributeFundsPull(address(minipool), true);

    assertEq(address(rpRecipient).balance, 1 ether);
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardRecipient.balance, 0.5 ether);

    assertEq(rpRecipient.getPullBalance(principalRecipient), 0);
    assertEq(rpRecipient.getPullBalance(rewardRecipient), 1 ether);

    assertEq(rpRecipient.fundsPendingWithdrawal(), 1 ether);

    address(minipool).safeTransferETH(1 ether);
    assertEq(address(minipool).balance, 1 ether);

    rpRecipient.distributeFunds(address(minipool), true);
    assertEq(address(rpRecipient).balance, 1 ether);
    assertEq(principalRecipient.balance, 0);
    assertEq(rewardRecipient.balance, 1.5 ether);

    assertEq(rpRecipient.getPullBalance(principalRecipient), 0 ether);
    assertEq(rpRecipient.getPullBalance(rewardRecipient), 1 ether);

    assertEq(rpRecipient.fundsPendingWithdrawal(), 1 ether);

    rpRecipient.withdraw(rewardRecipient);
    assertEq(address(rpRecipient).balance, 0 ether);
    assertEq(principalRecipient.balance, 0);
    assertEq(rewardRecipient.balance, 2.5 ether);

    assertEq(rpRecipient.getPullBalance(principalRecipient), 0 ether);
    assertEq(rpRecipient.getPullBalance(rewardRecipient), 0 ether);

    assertEq(rpRecipient.fundsPendingWithdrawal(), 0);

    address(rpRecipient).safeTransferETH(1 ether);
    rpRecipient.withdraw(rewardRecipient);

    assertEq(address(rpRecipient).balance, 1 ether);
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardRecipient.balance, 2.5 ether);

    assertEq(rpRecipient.getPullBalance(principalRecipient), 0 ether);
    assertEq(rpRecipient.getPullBalance(rewardRecipient), 0 ether);

    assertEq(rpRecipient.fundsPendingWithdrawal(), 0 ether);
  }
}
