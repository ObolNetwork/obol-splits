// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ObolRocketPoolStorage} from "src/rocket-pool/ObolRocketPoolStorage.sol";

contract ObolRocketPoolStorageTest is Test {
  ObolRocketPoolStorage rpStorage;
  address user;

  function setUp() public {
    rpStorage = new ObolRocketPoolStorage();
    user = makeAddr("user");
  }

  function testSetPoolStorage() public {
    address newAddr = makeAddr("newAddr");

    vm.startPrank(user);
    vm.expectRevert();
    rpStorage.setPoolStorage(newAddr);
    vm.stopPrank();

    vm.expectRevert();
    rpStorage.setPoolStorage(address(0));

    rpStorage.setPoolStorage(newAddr);
    assertEq(rpStorage.rocketPoolStorage(), newAddr);
  }

  function testSetPoolDeposit() public {
    address newAddr = makeAddr("newAddr");

    vm.startPrank(user);
    vm.expectRevert();
    rpStorage.setPoolDeposit(newAddr);
    vm.stopPrank();

    vm.expectRevert();
    rpStorage.setPoolDeposit(address(0));

    rpStorage.setPoolDeposit(newAddr);
    assertEq(rpStorage.rocketPoolDeposit(), newAddr);
  }

  function testSetMinipoolManager() public {
    address newAddr = makeAddr("newAddr");

    vm.startPrank(user);
    vm.expectRevert();
    rpStorage.setMinipoolManager(newAddr);
    vm.stopPrank();

    vm.expectRevert();
    rpStorage.setMinipoolManager(address(0));

    rpStorage.setMinipoolManager(newAddr);
    assertEq(rpStorage.rocketPoolMinipoolManager(), newAddr);
  }

  function testSetRETH() public {
    address newAddr = makeAddr("newAddr");

    vm.startPrank(user);
    vm.expectRevert();
    rpStorage.setREth(newAddr);
    vm.stopPrank();

    vm.expectRevert();
    rpStorage.setREth(address(0));

    rpStorage.setREth(newAddr);
    assertEq(rpStorage.rEth(), newAddr);
  }
}
