// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ObolEigenLayerPodController} from "src/eigenlayer/ObolEigenLayerPodController.sol";
import {ObolEigenLayerPodControllerFactory} from "src/eigenlayer/ObolEigenLayerPodControllerFactory.sol";
import {
  IEigenPod,
  IDelegationManager,
  IEigenPodManager,
  IEigenLayerUtils,
  IDelayedWithdrawalRouter
} from "src/interfaces/external/IEigenLayer.sol";
import {MockERC20} from "src/test/utils/mocks/MockERC20.sol";
import {ISplitMain} from "src/interfaces/external/splits/ISplitMain.sol";
import {
  OptimisticWithdrawalRecipientFactory,
  OptimisticWithdrawalRecipient
} from "src/owr/OptimisticWithdrawalRecipientFactory.sol";
import {IENSReverseRegistrar} from "../../../interfaces/external/IENSReverseRegistrar.sol";
import {EigenLayerTestBase} from "src/test/eigenlayer/EigenLayerTestBase.sol";

contract OELPCIntegration is EigenLayerTestBase {
  ObolEigenLayerPodControllerFactory factory;
  ObolEigenLayerPodController owrController;
  ObolEigenLayerPodController splitController;

  address[] accounts;
  uint32[] percentAllocations;

  address owner;
  address user1;
  address user2;

  address owrWithdrawalAddress;
  address splitWithdrawalAddress;

  address principalRecipient;
  address rewardRecipient;
  address feeRecipient;

  uint256 feeShare;

  function setUp() public {
    uint256 goerliBlock = 10_653_080;
    vm.createSelectFork(getChain("goerli").rpcUrl);

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

    owner = makeAddr("owner");
    user1 = makeAddr("user1");
    user1 = makeAddr("user2");
    principalRecipient = makeAddr("principalRecipient");
    rewardRecipient = makeAddr("rewardRecipient");
    feeRecipient = makeAddr("feeRecipient");
    feeShare = 1e3;

    OptimisticWithdrawalRecipientFactory owrFactory =
      new OptimisticWithdrawalRecipientFactory("demo.obol.eth", ENS_REVERSE_REGISTRAR_GOERLI, address(this));

    owrWithdrawalAddress =
      address(owrFactory.createOWRecipient(address(0), principalRecipient, rewardRecipient, 32 ether));

    factory = new ObolEigenLayerPodControllerFactory(
      feeRecipient, feeShare, DELEGATION_MANAGER_GOERLI, POD_MANAGER_GOERLI, DELAY_ROUTER_GOERLI
    );

    owrController = ObolEigenLayerPodController(factory.createPodController(owner, owrWithdrawalAddress));

    accounts = new address[](2);
    accounts[0] = makeAddr("accounts0");
    accounts[1] = makeAddr("accounts1");

    percentAllocations = new uint32[](2);
    percentAllocations[0] = 300_000;
    percentAllocations[1] = 700_000;

    splitWithdrawalAddress = ISplitMain(SPLIT_MAIN_GOERLI).createSplit(accounts, percentAllocations, 0, address(0));

    splitController = ObolEigenLayerPodController(factory.createPodController(owner, splitWithdrawalAddress));

    vm.prank(DELAY_ROUTER_OWNER_GOERLI);
    // set the delay withdrawal duration to zero
    IDelayedWithdrawalRouter(DELAY_ROUTER_GOERLI).setWithdrawalDelayBlocks(0);
  }

  function testFuzz_WithdrawOWR(uint256 amountToDeposit) external {
    vm.assume(amountToDeposit > 0);

    uint256 stakeSize = 32 ether;

    amountToDeposit = boundETH(amountToDeposit);
    // transfer unstake beacon eth to eigenPod
    (bool success,) = address(owrController.eigenPod()).call{value: amountToDeposit}("");
    require(success, "call failed");

    vm.startPrank(owner);
    {
      owrController.callEigenPod(encodeEigenPodCall(address(owrController), amountToDeposit));
      owrController.claimDelayedWithdrawals(1);
    }
    vm.stopPrank();

    uint256 fee = amountToDeposit * feeShare / PERCENTAGE_SCALE;

    assertEq(address(feeRecipient).balance, fee, "fee recipient balance increased");

    uint256 owrBalance = amountToDeposit - fee;
    assertEq(address(owrWithdrawalAddress).balance, owrBalance, "owr balance increased");

    // call distribute on owrWithdrawal address
    OptimisticWithdrawalRecipient(owrWithdrawalAddress).distributeFunds();

    // check the princiapl recipient
    if (owrBalance >= BALANCE_CLASSIFICATION_THRESHOLD) {
      if (owrBalance > stakeSize) {
        // prinicipal rexeives 32 eth and reward recieves remainder
        assertEq(address(principalRecipient).balance, stakeSize, "invalid principal balance");
        assertEq(address(rewardRecipient).balance, owrBalance - stakeSize, "invalid reward balance");
      } else {
        // principal receives everything
        assertEq(address(principalRecipient).balance, owrBalance, "invalid principal balance");
      }
    } else {
      // reward recipient receives everything
      assertEq(address(rewardRecipient).balance, owrBalance, "invalid reward balance");
    }
  }

  function testFuzz_WithdrawSplit(uint256 amountToDeposit) external {
    vm.assume(amountToDeposit > 0);

    amountToDeposit = boundETH(amountToDeposit);
    // transfer unstake beacon eth to eigenPod
    (bool success,) = address(splitController.eigenPod()).call{value: amountToDeposit}("");
    require(success, "call failed");

    vm.startPrank(owner);
    {
      splitController.callEigenPod(encodeEigenPodCall(address(splitController), amountToDeposit));
      splitController.claimDelayedWithdrawals(1);
    }
    vm.stopPrank();

    uint256 fee = amountToDeposit * feeShare / PERCENTAGE_SCALE;
    assertEq(address(feeRecipient).balance, fee, "fee recipient balance increased");

    uint256 splitBalance = amountToDeposit - fee;

    assertEq(address(splitWithdrawalAddress).balance, splitBalance, "invalid balance");
  }

  function boundETH(uint256 amount) internal view returns (uint256 result) {
    result = bound(amount, 1, type(uint96).max);
  }
}
