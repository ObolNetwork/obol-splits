// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ObolValidatorManager} from "src/ovm/ObolValidatorManager.sol";
import {ObolValidatorManagerFactory} from "src/ovm/ObolValidatorManagerFactory.sol";
import {MockERC20} from "../utils/mocks/MockERC20.sol";
import {SystemContractMock} from "./mocks/SystemContractMock.sol";
import {DepositContractMock} from "./mocks/DepositContractMock.sol";
import {IENSReverseRegistrar} from "../../interfaces/IENSReverseRegistrar.sol";

contract ObolValidatorManagerFactoryTest is Test {
  event CreateObolValidatorManager(
    address indexed owr,
    address indexed owner,
    address recoveryAddress,
    address principalRecipient,
    address rewardRecipient,
    uint64 principalThreshold
  );

  address public ENS_REVERSE_REGISTRAR = 0x084b1c3C81545d370f3634392De611CaaBFf8148;

  uint64 public constant BALANCE_CLASSIFICATION_THRESHOLD_GWEI = 16 ether / 1 gwei;

  SystemContractMock consolidationMock;
  SystemContractMock withdrawalMock;
  DepositContractMock depositMock;
  ObolValidatorManagerFactory owrFactory;

  address public recoveryAddress;
  address public principalRecipient;
  address public rewardsRecipient;
  uint64 public principalThreshold;

  function setUp() public {
    vm.mockCall(
      ENS_REVERSE_REGISTRAR,
      abi.encodeWithSelector(IENSReverseRegistrar.setName.selector),
      bytes.concat(bytes32(0))
    );
    vm.mockCall(
      ENS_REVERSE_REGISTRAR,
      abi.encodeWithSelector(IENSReverseRegistrar.claim.selector),
      bytes.concat(bytes32(0))
    );

    consolidationMock = new SystemContractMock(48 + 48);
    withdrawalMock = new SystemContractMock(48 + 8);
    depositMock = new DepositContractMock();

    owrFactory = new ObolValidatorManagerFactory(
      address(consolidationMock),
      address(withdrawalMock),
      address(depositMock),
      "demo.obol.eth",
      ENS_REVERSE_REGISTRAR,
      address(this)
    );

    recoveryAddress = makeAddr("recoveryAddress");
    principalRecipient = makeAddr("principalRecipient");
    rewardsRecipient = makeAddr("rewardsRecipient");
    principalThreshold = BALANCE_CLASSIFICATION_THRESHOLD_GWEI;
  }

  function testCan_createOWRecipient() public {
    ObolValidatorManager owr = owrFactory.createObolValidatorManager(
      address(this),
      principalRecipient,
      rewardsRecipient,
      recoveryAddress,
      principalThreshold
    );
    assertEq(owr.owner(), address(this));
    assertEq(address(owr.consolidationSystemContract()), address(consolidationMock));
    assertEq(address(owr.withdrawalSystemContract()), address(withdrawalMock));

    recoveryAddress = address(0);
    owr = owrFactory.createObolValidatorManager(
      address(this),
      principalRecipient,
      rewardsRecipient,
      recoveryAddress,
      principalThreshold
    );
    assertEq(owr.recoveryAddress(), address(0));
  }

  function testCan_emitOnCreate() public {
    // don't check deploy address
    vm.expectEmit(false, true, true, true);

    emit CreateObolValidatorManager(
      address(0xdead),
      address(this),
      recoveryAddress,
      principalRecipient,
      rewardsRecipient,
      principalThreshold
    );
    owrFactory.createObolValidatorManager(
      address(this),
      principalRecipient,
      rewardsRecipient,
      recoveryAddress,
      principalThreshold
    );

    recoveryAddress = address(0);

    // don't check deploy address
    vm.expectEmit(false, true, true, true);
    emit CreateObolValidatorManager(
      address(0xdead),
      address(this),
      recoveryAddress,
      principalRecipient,
      rewardsRecipient,
      principalThreshold
    );
    owrFactory.createObolValidatorManager(
      address(this),
      principalRecipient,
      rewardsRecipient,
      recoveryAddress,
      principalThreshold
    );
  }

  function testCannot_createWithInvalidRecipients() public {
    vm.expectRevert(ObolValidatorManagerFactory.Invalid__Recipients.selector);
    owrFactory.createObolValidatorManager(
      address(this),
      address(0),
      rewardsRecipient,
      recoveryAddress,
      principalThreshold
    );

    vm.expectRevert(ObolValidatorManagerFactory.Invalid__Recipients.selector);
    owrFactory.createObolValidatorManager(address(this), address(0), address(0), recoveryAddress, principalThreshold);

    vm.expectRevert(ObolValidatorManagerFactory.Invalid__Recipients.selector);
    owrFactory.createObolValidatorManager(
      address(this),
      principalRecipient,
      address(0),
      recoveryAddress,
      principalThreshold
    );
  }

  function testCannot_createWithInvalidThreshold() public {
    principalThreshold = 0;

    vm.expectRevert(ObolValidatorManagerFactory.Invalid__ZeroThreshold.selector);
    owrFactory.createObolValidatorManager(
      address(this),
      principalRecipient,
      rewardsRecipient,
      recoveryAddress,
      principalThreshold
    );

    vm.expectRevert(ObolValidatorManagerFactory.Invalid__ThresholdTooLarge.selector);
    owrFactory.createObolValidatorManager(
      address(this),
      principalRecipient,
      rewardsRecipient,
      recoveryAddress,
      type(uint64).max
    );
  }

  /// -----------------------------------------------------------------------
  /// Fuzzing Tests
  /// ----------------------------------------------------------------------

  function testFuzzCan_createOWRecipient(uint64 _threshold) public {
    vm.assume(_threshold > 0 && _threshold < 2048 * 1e9);

    vm.expectEmit(false, true, true, true);
    emit CreateObolValidatorManager(
      address(0xdead),
      address(this),
      recoveryAddress,
      principalRecipient,
      rewardsRecipient,
      _threshold
    );
    owrFactory.createObolValidatorManager(
      address(this),
      principalRecipient,
      rewardsRecipient,
      recoveryAddress,
      _threshold
    );
  }

  function testFuzzCannot_CreateWithZeroThreshold(address _rewardsRecipient) public {
    vm.assume(_rewardsRecipient != address(0));
    principalThreshold = 0;

    // eth
    vm.expectRevert(ObolValidatorManagerFactory.Invalid__ZeroThreshold.selector);
    owrFactory.createObolValidatorManager(
      address(this),
      principalRecipient,
      _rewardsRecipient,
      recoveryAddress,
      principalThreshold
    );
  }

  function testFuzzCannot_CreateWithLargeThreshold(address _rewardsRecipient, uint64 _threshold) public {
    vm.assume(_threshold > 2048 * 1e9);
    vm.assume(_rewardsRecipient != address(0));

    vm.expectRevert(ObolValidatorManagerFactory.Invalid__ThresholdTooLarge.selector);
    owrFactory.createObolValidatorManager(
      address(this),
      principalRecipient,
      _rewardsRecipient,
      recoveryAddress,
      _threshold
    );
  }
}
