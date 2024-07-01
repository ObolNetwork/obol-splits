// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {
  ImmutableSplitControllerFactory,
  ImmutableSplitController
} from "src/controllers/ImmutableSplitControllerFactory.sol";
import {ISplitMain} from "src/interfaces/external/splits/ISplitMain.sol";

contract IMSCFactory is Test {
  error Invalid_Address();
  error Invalid_Owner();
  error InvalidSplit_Address();
  error InvalidSplit__TooFewAccounts(uint256 accountsLength);
  error InvalidSplit__AccountsAndAllocationsMismatch(uint256 accountsLength, uint256 allocationsLength);
  error InvalidSplit__InvalidAllocationsSum(uint32 allocationsSum);
  error InvalidSplit__AccountsOutOfOrder(uint256 index);
  error InvalidSplit__AllocationMustBePositive(uint256 index);
  error InvalidSplit__InvalidDistributorFee(uint32 distributorFee);

  address internal SPLIT_MAIN_GOERLI = 0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE;
  uint32 public constant SPLIT_MAIN_PERCENTAGE_SCALE = 1e6;
  uint256 public constant PERCENTAGE_SCALE = 1e6;

  ImmutableSplitControllerFactory public factory;
  ImmutableSplitController public cntrlImpl;

  address owner;

  address[] accounts;
  uint32[] percentAllocations;

  function setUp() public {
    vm.createSelectFork(getChain("goerli").rpcUrl);

    factory = new ImmutableSplitControllerFactory(SPLIT_MAIN_GOERLI);
    cntrlImpl = factory.controller();

    accounts = new address[](2);
    accounts[0] = makeAddr("accounts0");
    accounts[1] = makeAddr("accounts1");

    percentAllocations = new uint32[](2);
    percentAllocations[0] = 400_000;
    percentAllocations[1] = 600_000;

    owner = makeAddr("owner");
  }

  function test_RevertIfSplitMainIsInvalid() public {
    vm.expectRevert(Invalid_Address.selector);
    new ImmutableSplitControllerFactory(address(0));
  }

  function test_RevertIfAccountSizeIsOne() public {
    address[] memory newAccounts = new address[](1);
    newAccounts[0] = makeAddr("testRevertIfAccountSizeIsOne");

    vm.expectRevert(abi.encodeWithSelector(InvalidSplit__TooFewAccounts.selector, newAccounts.length));

    factory.createController(
      address(1), owner, newAccounts, percentAllocations, 0, keccak256(abi.encodePacked(uint256(12)))
    );
  }

  function test_RevertIfAccountAndAllocationMismatch() public {
    uint32[] memory newPercentAllocations = new uint32[](3);
    newPercentAllocations[0] = 200_000;
    newPercentAllocations[1] = 200_000;
    newPercentAllocations[2] = 600_000;

    vm.expectRevert(
      abi.encodeWithSelector(
        InvalidSplit__AccountsAndAllocationsMismatch.selector, accounts.length, newPercentAllocations.length
      )
    );

    factory.createController(
      address(1), owner, accounts, newPercentAllocations, 0, keccak256(abi.encodePacked(uint256(12)))
    );
  }

  function test_RevertIfAccountOutOfOrder() public {
    address[] memory newAccounts = new address[](2);
    newAccounts[0] = address(0x4);
    newAccounts[1] = address(0x1);

    vm.expectRevert(abi.encodeWithSelector(InvalidSplit__AccountsOutOfOrder.selector, 0));

    factory.createController(
      address(1), owner, newAccounts, percentAllocations, 0, keccak256(abi.encodePacked(uint256(12)))
    );
  }

  function test_RevertIfZeroPercentAllocation() public {
    uint32[] memory newPercentAllocations = new uint32[](2);
    newPercentAllocations[0] = SPLIT_MAIN_PERCENTAGE_SCALE;
    newPercentAllocations[1] = 0;

    vm.expectRevert(abi.encodeWithSelector(InvalidSplit__AllocationMustBePositive.selector, 1));

    factory.createController(
      address(1), owner, accounts, newPercentAllocations, 0, keccak256(abi.encodePacked(uint256(12)))
    );
  }

  function test_RevertIfInvalidDistributorFee() public {
    uint32 invalidDistributorFee = 1e6;

    vm.expectRevert(abi.encodeWithSelector(InvalidSplit__InvalidDistributorFee.selector, invalidDistributorFee));

    factory.createController(
      address(1), owner, accounts, percentAllocations, invalidDistributorFee, keccak256(abi.encodePacked(uint256(12)))
    );
  }

  function test_RevertIfInvalidAllocationSum() public {
    uint32[] memory newPercentAllocations = new uint32[](2);
    newPercentAllocations[0] = SPLIT_MAIN_PERCENTAGE_SCALE;
    newPercentAllocations[1] = 1;

    vm.expectRevert(
      abi.encodeWithSelector(InvalidSplit__InvalidAllocationsSum.selector, SPLIT_MAIN_PERCENTAGE_SCALE + 1)
    );

    factory.createController(
      address(1), owner, accounts, newPercentAllocations, 0, keccak256(abi.encodePacked(uint256(12)))
    );
  }

  function test_RevertIfInvalidOwner() public {
    vm.expectRevert(Invalid_Owner.selector);

    factory.createController(
      address(1), address(0), accounts, percentAllocations, 0, keccak256(abi.encodePacked(uint256(123)))
    );
  }

  function test_RevertIfInvalidSplitAddress() public {
    vm.expectRevert(InvalidSplit_Address.selector);

    factory.createController(
      address(0), address(1), accounts, percentAllocations, 0, keccak256(abi.encodePacked(uint256(123)))
    );
  }

  function test_RevertIfRecipeintSizeTooMany() public {
    bytes32 deploymentSalt = keccak256(abi.encodePacked(uint256(1102)));

    uint256 size = 400;
    address[] memory localAccounts = _generateAddresses(1, size);
    uint32[] memory localAllocations = _generatePercentAlloc(size);

    vm.expectRevert(
      abi.encodeWithSelector(ImmutableSplitControllerFactory.InvalidSplit__TooManyAccounts.selector, size)
    );

    factory.createController(address(1), owner, localAccounts, localAllocations, 0, deploymentSalt);
  }

  function test_CanCreateController() public {
    bytes32 deploymentSalt = keccak256(abi.encodePacked(uint256(1102)));

    address predictedAddress =
      factory.predictSplitControllerAddress(owner, accounts, percentAllocations, 0, deploymentSalt);

    address split = ISplitMain(SPLIT_MAIN_GOERLI).createSplit(accounts, percentAllocations, 0, predictedAddress);

    ImmutableSplitController controller =
      factory.createController(split, owner, accounts, percentAllocations, 0, deploymentSalt);

    assertEq(address(controller), predictedAddress, "predicted_address_invalid");
  }

  function _generateAddresses(uint256 _seed, uint256 size) internal pure returns (address[] memory accts) {
    accts = new address[](size);
    uint160 seed = uint160(uint256(keccak256(abi.encodePacked(_seed))));
    for (uint160 i; i < size; i++) {
      accts[i] = address(seed);
      seed += 1;
    }
  }

  function _generatePercentAlloc(uint256 size) internal pure returns (uint32[] memory alloc) {
    alloc = new uint32[](size);
    for (uint256 i; i < size; i++) {
      alloc[i] = uint32(PERCENTAGE_SCALE / size);
    }

    if (PERCENTAGE_SCALE % size != 0) alloc[size - 1] += uint32(PERCENTAGE_SCALE % size);
  }
}
