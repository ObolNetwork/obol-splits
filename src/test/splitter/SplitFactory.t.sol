// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import {SplitFactory, InvalidConfig} from "src/splitter/SplitFactory.sol";
import {SplitMainV2} from "src/splitter/SplitMainV2.sol";
import {SplitWallet, Unauthorized} from "src/splitter/SplitWallet.sol";

contract XSplitFactoryTest is Test {

  error IdExists(bytes32 id);

  event NewSplitWallet(bytes32 indexed id, address implementation);

  SplitFactory public splitFactory;
  SplitMainV2 public splitMainV2;
  SplitWallet public splitWallet;

  address user1;

  address[] accounts;
  uint32[]  percentAllocations;

  bytes32 internal splitWalletId = keccak256("splitWallet");

  function setUp() public {
    splitFactory = new SplitFactory(address(this));
    // fetch splitMain from splitFactory
    splitMainV2 = SplitMainV2(payable(address(splitFactory.splitMain())));
    splitWallet = new SplitWallet(address(splitMainV2));

    user1 = makeAddr("user1");

    accounts = new address[](2);
    accounts[0] = makeAddr("accounts0");
    accounts[1] = makeAddr("accounts1");

    percentAllocations = new uint32[](2);
    percentAllocations[0] = 400_000;
    percentAllocations[1] = 600_000;
  }

  function testAddSplitWalletInvalidImplementation() public {
    vm.expectRevert();
    splitFactory.addSplitWallet(splitWalletId, address(0));
  }

  function testAddSplitWallet() public {
    vm.expectEmit(true, false, false, false, address(splitFactory));
    emit NewSplitWallet(splitWalletId, address(splitWallet));

    splitFactory.addSplitWallet(splitWalletId, address(splitWallet));

    vm.expectRevert();
    splitFactory.addSplitWallet(splitWalletId, address(splitWallet));
  }

  function testCheckSplitFactoryOwner() public {
    assertEq(
      splitFactory.owner(),
      address(this)
    );
  }

  function testCanChangeSplitFactoryOwner() public {
    vm.prank(user1);
    splitFactory.requestOwnershipHandover();

    splitFactory.completeOwnershipHandover(user1);
  }

  function testNonOwnerCannotAddSplitWallet() public {
    vm.expectRevert(Unauthorized.selector);
    vm.prank(user1);
    splitFactory.addSplitWallet(splitWalletId, address(splitWallet));
  }

  function testCreateSplit() public {
    // add split wallet
    splitFactory.addSplitWallet(splitWalletId, address(splitWallet));

    address predictedSplitAddress = splitFactory.predictImmutableSplitAddress(
      splitWalletId, accounts, percentAllocations, 0
    );

    address splitter = splitFactory.createSplit(splitWalletId, accounts, percentAllocations, 0, address(this), address(0));


    assertEq(predictedSplitAddress, splitter);
  }

  function testCreateSplitInvalidSplutWalletId() public {
    vm.expectRevert();
    
    splitFactory.createSplit(bytes32("2"), accounts, percentAllocations, 0, address(this), address(0));
  }

}
