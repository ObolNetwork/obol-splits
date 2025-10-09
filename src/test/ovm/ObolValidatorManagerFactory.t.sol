// SPDX-License-Identifier: Proprietary
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
    address indexed ovm,
    address indexed owner,
    address beneficiaryRecipient,
    address rewardRecipient,
    uint64 principalThreshold
  );

  address public ENS_REVERSE_REGISTRAR = 0x084b1c3C81545d370f3634392De611CaaBFf8148;

  uint64 public constant BALANCE_CLASSIFICATION_THRESHOLD_GWEI = 16 ether / 1 gwei;

  SystemContractMock consolidationMock;
  SystemContractMock withdrawalMock;
  DepositContractMock depositMock;
  ObolValidatorManagerFactory ovmFactory;

  address public beneficiaryRecipient;
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

    ovmFactory = new ObolValidatorManagerFactory(
      address(consolidationMock),
      address(withdrawalMock),
      address(depositMock),
      "demo.obol.eth",
      ENS_REVERSE_REGISTRAR,
      address(this)
    );

    beneficiaryRecipient = makeAddr("beneficiaryRecipient");
    rewardsRecipient = makeAddr("rewardsRecipient");
    principalThreshold = BALANCE_CLASSIFICATION_THRESHOLD_GWEI;
  }

  function testCan_createOVM() public {
    ObolValidatorManager ovm = ovmFactory.createObolValidatorManager(
      address(this),
      beneficiaryRecipient,
      rewardsRecipient,
      principalThreshold
    );
    assertEq(ovm.owner(), address(this));
    assertEq(address(ovm.consolidationSystemContract()), address(consolidationMock));
    assertEq(address(ovm.withdrawalSystemContract()), address(withdrawalMock));
  }

  function testCan_emitOnCreate() public {
    // don't check deploy address
    vm.expectEmit(false, true, true, true);

    emit CreateObolValidatorManager(
      address(0xdead),
      address(this),
      beneficiaryRecipient,
      rewardsRecipient,
      principalThreshold
    );
    ovmFactory.createObolValidatorManager(
      address(this),
      beneficiaryRecipient,
      rewardsRecipient,
      principalThreshold
    );

    // don't check deploy address
    vm.expectEmit(false, true, true, true);
    emit CreateObolValidatorManager(
      address(0xdead),
      address(this),
      beneficiaryRecipient,
      rewardsRecipient,
      principalThreshold
    );
    ovmFactory.createObolValidatorManager(
      address(this),
      beneficiaryRecipient,
      rewardsRecipient,
      principalThreshold
    );
  }

  function testCannot_createWithInvalidOwner() public {
    vm.expectRevert(ObolValidatorManagerFactory.Invalid_Owner.selector);
    ovmFactory.createObolValidatorManager(
      address(0),
      beneficiaryRecipient,
      rewardsRecipient,
      principalThreshold
    );
  }

  function testCannot_createWithInvalidRecipients() public {
    vm.expectRevert(ObolValidatorManagerFactory.Invalid__Recipients.selector);
    ovmFactory.createObolValidatorManager(
      address(this),
      address(0),
      rewardsRecipient,
      principalThreshold
    );

    vm.expectRevert(ObolValidatorManagerFactory.Invalid__Recipients.selector);
    ovmFactory.createObolValidatorManager(address(this), address(0), address(0), principalThreshold);

    vm.expectRevert(ObolValidatorManagerFactory.Invalid__Recipients.selector);
    ovmFactory.createObolValidatorManager(
      address(this),
      beneficiaryRecipient,
      address(0),
      principalThreshold
    );
  }

  function testCannot_createWithInvalidThreshold() public {
    principalThreshold = 0;

    vm.expectRevert(ObolValidatorManagerFactory.Invalid__ZeroThreshold.selector);
    ovmFactory.createObolValidatorManager(
      address(this),
      beneficiaryRecipient,
      rewardsRecipient,
      principalThreshold
    );

    vm.expectRevert(ObolValidatorManagerFactory.Invalid__ThresholdTooLarge.selector);
    ovmFactory.createObolValidatorManager(
      address(this),
      beneficiaryRecipient,
      rewardsRecipient,
      type(uint64).max
    );
  }

  /// -----------------------------------------------------------------------
  /// Fuzzing Tests
  /// ----------------------------------------------------------------------

  function testFuzzCan_createOVM(uint64 _threshold) public {
    vm.assume(_threshold > 0 && _threshold < 2048 * 1e9);

    vm.expectEmit(false, true, true, true);
    emit CreateObolValidatorManager(
      address(0xdead),
      address(this),
      beneficiaryRecipient,
      rewardsRecipient,
      _threshold
    );
    ovmFactory.createObolValidatorManager(
      address(this),
      beneficiaryRecipient,
      rewardsRecipient,
      _threshold
    );
  }

  function testFuzzCannot_CreateWithZeroThreshold(address _rewardsRecipient) public {
    vm.assume(_rewardsRecipient != address(0));
    principalThreshold = 0;

    // eth
    vm.expectRevert(ObolValidatorManagerFactory.Invalid__ZeroThreshold.selector);
    ovmFactory.createObolValidatorManager(
      address(this),
      beneficiaryRecipient,
      _rewardsRecipient,
      principalThreshold
    );
  }

  function testFuzzCannot_CreateWithLargeThreshold(address _rewardsRecipient, uint64 _threshold) public {
    vm.assume(_threshold > 2048 * 1e9);
    vm.assume(_rewardsRecipient != address(0));

    vm.expectRevert(ObolValidatorManagerFactory.Invalid__ThresholdTooLarge.selector);
    ovmFactory.createObolValidatorManager(
      address(this),
      beneficiaryRecipient,
      _rewardsRecipient,
      _threshold
    );
  }
}
