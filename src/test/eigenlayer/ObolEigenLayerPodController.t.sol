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
import {
  OptimisticWithdrawalRecipientFactory,
  OptimisticWithdrawalRecipient
} from "src/owr/OptimisticWithdrawalRecipientFactory.sol";
import {EigenLayerTestBase} from "src/test/eigenlayer/EigenLayerTestBase.sol";

interface IDepositContract {
  function deposit(
    bytes calldata pubkey,
    bytes calldata withdrawal_credentials,
    bytes calldata signature,
    bytes32 deposit_data_root
  ) external payable;
}

contract ObolEigenLayerPodControllerTest is EigenLayerTestBase {
  error Unauthorized();
  error AlreadyInitialized();
  error Invalid_FeeShare();
  error CallFailed(bytes);

  ObolEigenLayerPodControllerFactory factory;
  ObolEigenLayerPodControllerFactory zeroFeeFactory;

  ObolEigenLayerPodController controller;
  ObolEigenLayerPodController zeroFeeController;

  address owner;
  address user1;
  address user2;
  address withdrawalAddress;
  address principalRecipient;
  address feeRecipient;

  uint256 feeShare;

  MockERC20 mERC20;

  function setUp() public {
    vm.createSelectFork(getChain("goerli").rpcUrl);

    vm.mockCall(
      DEPOSIT_CONTRACT_GOERLI, abi.encodeWithSelector(IDepositContract.deposit.selector), bytes.concat(bytes32(0))
    );

    owner = makeAddr("owner");
    user1 = makeAddr("user1");
    user1 = makeAddr("user2");
    principalRecipient = makeAddr("principalRecipient");
    withdrawalAddress = makeAddr("withdrawalAddress");
    feeRecipient = makeAddr("feeRecipient");
    feeShare = 1e3;

    factory = new ObolEigenLayerPodControllerFactory(
      feeRecipient, feeShare, DELEGATION_MANAGER_GOERLI, POD_MANAGER_GOERLI, DELAY_ROUTER_GOERLI
    );

    zeroFeeFactory = new ObolEigenLayerPodControllerFactory(
      address(0), 0, DELEGATION_MANAGER_GOERLI, POD_MANAGER_GOERLI, DELAY_ROUTER_GOERLI
    );

    controller = ObolEigenLayerPodController(factory.createPodController(owner, withdrawalAddress));
    zeroFeeController = ObolEigenLayerPodController(zeroFeeFactory.createPodController(owner, withdrawalAddress));

    mERC20 = new MockERC20("Test Token", "TOK", 18);
    mERC20.mint(type(uint256).max);

    vm.prank(DELAY_ROUTER_OWNER_GOERLI);
    // set the delay withdrawal duration to zero
    IDelayedWithdrawalRouter(DELAY_ROUTER_GOERLI).setWithdrawalDelayBlocks(0);
  }

  function test_RevertIfInvalidFeeShare() external {
    vm.expectRevert(Invalid_FeeShare.selector);
    new ObolEigenLayerPodControllerFactory(
      feeRecipient, 1e7, DELEGATION_MANAGER_GOERLI, POD_MANAGER_GOERLI, DELAY_ROUTER_GOERLI
    );
  }

  function test_RevertIfNotOwnerCallEigenPod() external {
    vm.prank(user1);
    vm.expectRevert(Unauthorized.selector);
    controller.callEigenPod(encodeEigenPodCall(user1, 1 ether));
  }

  function test_RevertIfDoubleInitialize() external {
    vm.prank(user1);
    vm.expectRevert(AlreadyInitialized.selector);
    controller.initialize(owner, withdrawalAddress);
  }

  function test_CallEigenPod() external {
    address pod = controller.eigenPod();
    uint256 amount = 1 ether;

    // airdrop ether to pod
    (bool success,) = pod.call{value: amount}("");
    require(success, "call failed");

    vm.prank(owner);
    controller.callEigenPod(encodeEigenPodCall(user1, amount));
  }

  function test_CallDelegationManager() external {
    vm.prank(owner);
    controller.callDelegationManager(encodeDelegationManagerCall(EIGEN_LAYER_OPERATOR_GOERLI));
  }

  function test_OnlyOwnerCallDelegationManager() external {
    vm.prank(user1);
    vm.expectRevert(Unauthorized.selector);
    controller.callDelegationManager(encodeDelegationManagerCall(EIGEN_LAYER_OPERATOR_GOERLI));
  }

  function test_CallEigenPodManager() external {
    uint256 etherStake = 32 ether;
    vm.deal(owner, etherStake + 1 ether);
    vm.prank(owner);
    controller.callEigenPodManager{value: etherStake}(encodeEigenPodManagerCall(0));
  }

  function test_OnlyOwnerEigenPodManager() external {
    vm.expectRevert(Unauthorized.selector);
    controller.callEigenPodManager(encodeEigenPodManagerCall(0));
  }

  function test_ClaimDelayedWithdrawals() external {
    uint256 amountToDeposit = 2 ether;

    // transfer unstake beacon eth to eigenPod
    (bool success,) = address(controller.eigenPod()).call{value: amountToDeposit}("");
    require(success, "call failed");

    vm.startPrank(owner);
    {
      controller.callEigenPod(encodeEigenPodCall(address(controller), amountToDeposit));
      controller.claimDelayedWithdrawals(1);
    }
    vm.stopPrank();

    assertEq(address(feeRecipient).balance, 20_000_000_000_000_000, "fee recipient balance increased");
    assertEq(address(withdrawalAddress).balance, 1_980_000_000_000_000_000, "withdrawal balance increased");
  }

  function test_ClaimDelayedWithdrawalsZeroFee() external {
    uint256 amountToDeposit = 20 ether;

    // transfer unstake beacon eth to eigenPod
    (bool success,) = address(zeroFeeController.eigenPod()).call{value: amountToDeposit}("");
    require(success, "call failed");

    vm.startPrank(owner);
    {
      zeroFeeController.callEigenPod(encodeEigenPodCall(address(zeroFeeController), amountToDeposit));
      zeroFeeController.claimDelayedWithdrawals(1);
    }
    vm.stopPrank();

    assertEq(address(withdrawalAddress).balance, amountToDeposit, "withdrawal balance increased");
  }

  function test_InvalidCallReverts() external {
    uint256 amountToDeposit = 20 ether;
    bytes memory data = encodeEigenPodCall(address(0x2), amountToDeposit);
    vm.expectRevert(abi.encodeWithSelector(CallFailed.selector, data));
    vm.prank(owner);
    zeroFeeController.callEigenPod(data);
    vm.stopPrank();
  }

  function testFuzz_ClaimDelayedWithdrawals(uint256 amount) external {
    amount = bound(amount, _min(amount, address(this).balance), type(uint96).max);

    address DELAY_ROUTER_OWNER = 0x37bAFb55BC02056c5fD891DFa503ee84a97d89bF;
    vm.prank(DELAY_ROUTER_OWNER);
    // set the delay withdrawal duration to zero
    IDelayedWithdrawalRouter(DELAY_ROUTER_GOERLI).setWithdrawalDelayBlocks(0);

    // transfer unstake beacon eth to eigenPod
    (bool success,) = address(controller.eigenPod()).call{value: amount}("");
    require(success, "call failed");

    vm.startPrank(owner);
    {
      controller.callEigenPod(encodeEigenPodCall(address(controller), amount));
      controller.claimDelayedWithdrawals(1);
    }
    vm.stopPrank();

    uint256 fee = amount * feeShare / PERCENTAGE_SCALE;

    assertEq(address(feeRecipient).balance, fee, "invalid fee");

    assertEq(address(withdrawalAddress).balance, amount -= fee, "invalid withdrawalAddress balance");
  }

  function test_RescueFunds() external {
    uint256 amount = 1e18;
    mERC20.transfer(address(controller), amount);

    controller.rescueFunds(address(mERC20), amount);

    assertEq(mERC20.balanceOf(withdrawalAddress), amount, "could not rescue funds");
  }

  function test_RescueFundsZero() external {
    uint256 amount = 0;
    controller.rescueFunds(address(mERC20), amount);

    assertEq(mERC20.balanceOf(withdrawalAddress), amount, "balance should be zero");
  }
}
