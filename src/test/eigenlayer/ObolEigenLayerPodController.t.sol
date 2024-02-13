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
} from "src/interfaces/IEigenLayer.sol";
import {MockERC20} from "src/test/utils/mocks/MockERC20.sol";

interface IDepositContract {
  function deposit(
    bytes calldata pubkey,
    bytes calldata withdrawal_credentials,
    bytes calldata signature,
    bytes32 deposit_data_root
  ) external payable;
}

contract ObolEigenLayerPodControllerTest is Test {
  error Unauthorized();
  error AlreadyInitialized();

  uint256 internal constant PERCENTAGE_SCALE = 1e5;

  address constant DEPOSIT_CONTRACT_GOERLI = 0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b;
  address constant DELEGATION_MANAGER_GOERLI = 0x1b7b8F6b258f95Cf9596EabB9aa18B62940Eb0a8;
  address constant POD_MANAGER_GOERLI = 0xa286b84C96aF280a49Fe1F40B9627C2A2827df41;
  address constant DELAY_ROUTER_GOERLI = 0x89581561f1F98584F88b0d57c2180fb89225388f;

  address constant EIGEN_LAYER_OPERATOR_GOERLI = 0x3DeD1CB5E25FE3eC9811B918A809A371A4965A5D;

  ObolEigenLayerPodControllerFactory factory;
  ObolEigenLayerPodController controller;
  address owner;
  address user1;
  address user2;
  address splitter;
  address feeRecipient;

  uint256 feeShare;

  MockERC20 mERC20;

  function setUp() public {
    uint256 goerliBlock = 10_205_449;
    vm.createSelectFork(getChain("goerli").rpcUrl, goerliBlock);

    vm.mockCall(
      DEPOSIT_CONTRACT_GOERLI, abi.encodeWithSelector(IDepositContract.deposit.selector), bytes.concat(bytes32(0))
    );

    owner = makeAddr("owner");
    user1 = makeAddr("user1");
    user1 = makeAddr("user2");
    splitter = makeAddr("splitter");
    feeRecipient = makeAddr("feeRecipient");
    feeShare = 1e3;

    factory = new ObolEigenLayerPodControllerFactory(
      feeRecipient, feeShare, DELEGATION_MANAGER_GOERLI, POD_MANAGER_GOERLI, DELAY_ROUTER_GOERLI
    );

    controller = ObolEigenLayerPodController(factory.createPodController(owner, splitter));

    mERC20 = new MockERC20("Test Token", "TOK", 18);
    mERC20.mint(type(uint256).max);
  }

  function test_RevertIfNotOwnerCallEigenPod() external {
    vm.prank(user1);
    vm.expectRevert(Unauthorized.selector);
    controller.callEigenPod(encodeEigenPodCall(user1, 1 ether));
  }

  function test_RevertIfDoubleInitialize() external {
    vm.prank(user1);
    vm.expectRevert(AlreadyInitialized.selector);
    controller.initialize(owner, splitter);
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
    address DELAY_ROUTER_OWNER = 0x37bAFb55BC02056c5fD891DFa503ee84a97d89bF;
    vm.prank(DELAY_ROUTER_OWNER);
    // set the delay withdrawal duration to zero
    IDelayedWithdrawalRouter(DELAY_ROUTER_GOERLI).setWithdrawalDelayBlocks(0);

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

    assertEq(address(feeRecipient).balance, 20_000_000_000_000_000, "user balance increased");
    assertEq(address(splitter).balance, 1_980_000_000_000_000_000, "user balance increased");
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

    assertEq(address(splitter).balance, amount -= fee, "invalid splitter balance");
  }

  function test_RescueFunds() external {
    uint256 amount = 1e18;
    mERC20.transfer(address(controller), amount);

    controller.rescueFunds(address(mERC20), amount);

    assertEq(mERC20.balanceOf(splitter), amount, "could not rescue funds");
  }

  function encodeEigenPodCall(address recipient, uint256 amount) internal pure returns (bytes memory callData) {
    callData = abi.encodeCall(IEigenPod.withdrawNonBeaconChainETHBalanceWei, (recipient, amount));
  }

  function encodeDelegationManagerCall(address operator) internal pure returns (bytes memory callData) {
    IEigenLayerUtils.SignatureWithExpiry memory signature = IEigenLayerUtils.SignatureWithExpiry(bytes(""), 0);
    callData = abi.encodeCall(IDelegationManager.delegateTo, (operator, signature, bytes32(0)));
  }

  function encodeEigenPodManagerCall(uint256) internal pure returns (bytes memory callData) {
    bytes memory pubkey = bytes("");
    bytes memory signature = bytes("");
    bytes32 dataRoot = bytes32(0);

    callData = abi.encodeCall(IEigenPodManager.stake, (pubkey, signature, dataRoot));
  }

  function _min(uint256 a, uint256 b) internal pure returns (uint256 min) {
    min = a > b ? b : a;
  }

  function _max(uint256 a, uint256 b) internal pure returns (uint256 max) {
    max = a > b ? a : b;
  }
}
