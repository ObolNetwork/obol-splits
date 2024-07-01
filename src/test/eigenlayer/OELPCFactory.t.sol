// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ObolEigenLayerPodControllerFactory} from "src/eigenlayer/ObolEigenLayerPodControllerFactory.sol";
import {EigenLayerTestBase} from "src/test/eigenlayer/EigenLayerTestBase.sol";

contract ObolEigenLayerPodControllerFactoryTest is EigenLayerTestBase {
  error Invalid_Owner();
  error Invalid_WithdrawalAddress();
  error Invalid_DelegationManager();
  error Invalid_EigenPodManaager();
  error Invalid_WithdrawalRouter();

  event CreatePodController(address indexed controller, address indexed split, address owner);

  ObolEigenLayerPodControllerFactory factory;

  address owner;
  address user1;
  address withdrawalAddress;
  address feeRecipient;

  uint256 feeShare;

  function setUp() public {
    vm.createSelectFork(getChain("goerli").rpcUrl);

    owner = makeAddr("owner");
    user1 = makeAddr("user1");
    withdrawalAddress = makeAddr("withdrawalAddress");
    feeRecipient = makeAddr("feeRecipient");
    feeShare = 1e3;

    factory = new ObolEigenLayerPodControllerFactory(
      feeRecipient, feeShare, DELEGATION_MANAGER_GOERLI, POD_MANAGER_GOERLI, DELAY_ROUTER_GOERLI
    );
  }

  function test_RevertIfInvalidDelegationManger() external {
    vm.expectRevert(Invalid_DelegationManager.selector);
    new ObolEigenLayerPodControllerFactory(feeRecipient, feeShare, address(0), POD_MANAGER_GOERLI, DELAY_ROUTER_GOERLI);
  }

  function test_RevertIfInvalidPodManger() external {
    vm.expectRevert(Invalid_EigenPodManaager.selector);
    new ObolEigenLayerPodControllerFactory(
      feeRecipient, feeShare, DELEGATION_MANAGER_GOERLI, address(0), DELAY_ROUTER_GOERLI
    );
  }

  function test_RevertIfInvalidWithdrawalRouter() external {
    vm.expectRevert(Invalid_WithdrawalRouter.selector);
    new ObolEigenLayerPodControllerFactory(
      feeRecipient, feeShare, DELEGATION_MANAGER_GOERLI, POD_MANAGER_GOERLI, address(0)
    );
  }

  function test_RevertIfOwnerIsZero() external {
    vm.expectRevert(Invalid_Owner.selector);
    factory.createPodController(address(0), withdrawalAddress);
  }

  function test_RevertIfOWRIsZero() external {
    vm.expectRevert(Invalid_WithdrawalAddress.selector);
    factory.createPodController(user1, address(0));
  }

  function test_CreatePodController() external {
    vm.expectEmit(false, false, false, true);

    emit CreatePodController(address(0), withdrawalAddress, user1);

    address predictedAddress = factory.predictControllerAddress(user1, withdrawalAddress);

    address createdAddress = factory.createPodController(user1, withdrawalAddress);

    assertEq(predictedAddress, createdAddress, "predicted address is equivalent");
  }
}
