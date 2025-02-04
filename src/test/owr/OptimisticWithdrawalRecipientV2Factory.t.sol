// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {OptimisticWithdrawalRecipientV2} from "src/owr/OptimisticWithdrawalRecipientV2.sol";
import {OptimisticWithdrawalRecipientV2Factory} from "src/owr/OptimisticWithdrawalRecipientV2Factory.sol";
import {MockERC20} from "../utils/mocks/MockERC20.sol";
import {SystemContractMock} from "./mocks/SystemContractMock.sol";
import {DepositContractMock} from "./mocks/DepositContractMock.sol";
import {IENSReverseRegistrar} from "../../interfaces/IENSReverseRegistrar.sol";

contract OptimisticWithdrawalRecipientV2FactoryTest is Test {
  event CreateOWRecipient(
    address indexed owr,
    address indexed owner,
    address recoveryAddress,
    address principalRecipient,
    address rewardRecipient,
    uint256 principalThreshold
  );

  address public ENS_REVERSE_REGISTRAR = 0x084b1c3C81545d370f3634392De611CaaBFf8148;

  uint256 public constant BALANCE_CLASSIFICATION_THRESHOLD = 16 ether;

  SystemContractMock consolidationMock;
  SystemContractMock withdrawalMock;
  DepositContractMock depositMock;
  OptimisticWithdrawalRecipientV2Factory owrFactory;

  address public recoveryAddress;
  address public principalRecipient;
  address public rewardsRecipient;
  uint256 public principalThreshold;

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

    owrFactory = new OptimisticWithdrawalRecipientV2Factory(
      "demo.obol.eth",
      ENS_REVERSE_REGISTRAR,
      address(this),
      address(consolidationMock),
      address(withdrawalMock),
      address(depositMock)
    );

    recoveryAddress = makeAddr("recoveryAddress");
    principalRecipient = makeAddr("principalRecipient");
    rewardsRecipient = makeAddr("rewardsRecipient");
    principalThreshold = BALANCE_CLASSIFICATION_THRESHOLD;
  }

  function testCan_createOWRecipient() public {
    OptimisticWithdrawalRecipientV2 owr = owrFactory.createOWRecipient(
      recoveryAddress,
      principalRecipient,
      rewardsRecipient,
      principalThreshold,
      address(this)
    );
    assertEq(owr.owner(), address(this));
    assertEq(address(owr.consolidationSystemContract()), address(consolidationMock));
    assertEq(address(owr.withdrawalSystemContract()), address(withdrawalMock));

    recoveryAddress = address(0);
    owr = owrFactory.createOWRecipient(
      recoveryAddress,
      principalRecipient,
      rewardsRecipient,
      principalThreshold,
      address(this)
    );
    assertEq(owr.recoveryAddress(), address(0));
  }

  function testCan_emitOnCreate() public {
    // don't check deploy address
    vm.expectEmit(false, true, true, true);

    emit CreateOWRecipient(
      address(0xdead),
      address(this),
      recoveryAddress,
      principalRecipient,
      rewardsRecipient,
      principalThreshold
    );
    owrFactory.createOWRecipient(
      recoveryAddress,
      principalRecipient,
      rewardsRecipient,
      principalThreshold,
      address(this)
    );

    recoveryAddress = address(0);

    // don't check deploy address
    vm.expectEmit(false, true, true, true);
    emit CreateOWRecipient(
      address(0xdead),
      address(this),
      recoveryAddress,
      principalRecipient,
      rewardsRecipient,
      principalThreshold
    );
    owrFactory.createOWRecipient(
      recoveryAddress,
      principalRecipient,
      rewardsRecipient,
      principalThreshold,
      address(this)
    );
  }

  function testCannot_createWithInvalidRecipients() public {
    vm.expectRevert(OptimisticWithdrawalRecipientV2Factory.Invalid__Recipients.selector);
    owrFactory.createOWRecipient(recoveryAddress, address(0), rewardsRecipient, principalThreshold, address(this));

    vm.expectRevert(OptimisticWithdrawalRecipientV2Factory.Invalid__Recipients.selector);
    owrFactory.createOWRecipient(recoveryAddress, address(0), address(0), principalThreshold, address(this));

    vm.expectRevert(OptimisticWithdrawalRecipientV2Factory.Invalid__Recipients.selector);
    owrFactory.createOWRecipient(recoveryAddress, principalRecipient, address(0), principalThreshold, address(this));
  }

  function testCannot_createWithInvalidThreshold() public {
    principalThreshold = 0;

    vm.expectRevert(OptimisticWithdrawalRecipientV2Factory.Invalid__ZeroThreshold.selector);
    owrFactory.createOWRecipient(
      recoveryAddress,
      principalRecipient,
      rewardsRecipient,
      principalThreshold,
      address(this)
    );

    vm.expectRevert(OptimisticWithdrawalRecipientV2Factory.Invalid__ThresholdTooLarge.selector);
    owrFactory.createOWRecipient(
      recoveryAddress,
      principalRecipient,
      rewardsRecipient,
      type(uint128).max,
      address(this)
    );
  }

  /// -----------------------------------------------------------------------
  /// Fuzzing Tests
  /// ----------------------------------------------------------------------

  function testFuzzCan_createOWRecipient(uint96 _threshold) public {
    vm.assume(_threshold > 0 && _threshold < 2048 ether);

    vm.expectEmit(false, true, true, true);
    emit CreateOWRecipient(
      address(0xdead),
      address(this),
      recoveryAddress,
      principalRecipient,
      rewardsRecipient,
      _threshold
    );
    owrFactory.createOWRecipient(recoveryAddress, principalRecipient, rewardsRecipient, _threshold, address(this));
  }

  function testFuzzCannot_CreateWithZeroThreshold(address _rewardsRecipient) public {
    vm.assume(_rewardsRecipient != address(0));
    principalThreshold = 0;

    // eth
    vm.expectRevert(OptimisticWithdrawalRecipientV2Factory.Invalid__ZeroThreshold.selector);
    owrFactory.createOWRecipient(
      recoveryAddress,
      principalRecipient,
      _rewardsRecipient,
      principalThreshold,
      address(this)
    );
  }

  function testFuzzCannot_CreateWithLargeThreshold(address _rewardsRecipient, uint256 _threshold) public {
    vm.assume(_threshold > type(uint96).max);
    vm.assume(_rewardsRecipient != address(0));

    vm.expectRevert(OptimisticWithdrawalRecipientV2Factory.Invalid__ThresholdTooLarge.selector);
    owrFactory.createOWRecipient(recoveryAddress, principalRecipient, _rewardsRecipient, _threshold, address(this));
  }
}
