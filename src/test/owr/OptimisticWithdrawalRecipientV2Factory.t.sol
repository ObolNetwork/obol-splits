// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {OptimisticWithdrawalRecipientV2} from "src/owr/OptimisticWithdrawalRecipientV2.sol";
import {OptimisticWithdrawalRecipientV2Factory} from "src/owr/OptimisticWithdrawalRecipientV2Factory.sol";
import {MockERC20} from "../utils/mocks/MockERC20.sol";
import {OWRTestHelper} from "../owr/OWRTestHelper.t.sol";
import {ConsolidationSystemContractMock} from "./pectra/ConsolidationSystemContractMock.sol";
import {WithdrawalSystemContractMock} from "./pectra/WithdrawalSystemContractMock.sol";
import {IENSReverseRegistrar} from "../../interfaces/IENSReverseRegistrar.sol";

contract OptimisticWithdrawalRecipientV2FactoryTest is OWRTestHelper, Test {
  event CreateOWRecipient(
    address indexed owr,
    address indexed owner,
    address recoveryAddress,
    address principalRecipient,
    address rewardRecipient,
    uint256 threshold
  );

  address public ENS_REVERSE_REGISTRAR = 0x084b1c3C81545d370f3634392De611CaaBFf8148;

  ConsolidationSystemContractMock consolidationMock;
  WithdrawalSystemContractMock withdrawalMock;
  OptimisticWithdrawalRecipientV2Factory owrFactory;

  address public recoveryAddress;
  address public principalRecipient;
  address public rewardRecipient;
  uint256 public threshold;

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

    consolidationMock = new ConsolidationSystemContractMock();
    withdrawalMock = new WithdrawalSystemContractMock();
    owrFactory = new OptimisticWithdrawalRecipientV2Factory(
      "demo.obol.eth",
      ENS_REVERSE_REGISTRAR,
      address(this),
      address(consolidationMock),
      address(withdrawalMock)
    );
    recoveryAddress = makeAddr("recoveryAddress");
    (principalRecipient, rewardRecipient) = generateTrancheRecipients(10);
    threshold = ETH_STAKE;
  }

  function testCan_createOWRecipient() public {
    OptimisticWithdrawalRecipientV2 owr = owrFactory.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold, address(this));
    assertEq(owr.owner(), address(this));
    assertEq(address(owr.consolidationSystemContract()), address(consolidationMock));
    assertEq(address(owr.withdrawalSystemContract()), address(withdrawalMock));

    recoveryAddress = address(0);
    owr = owrFactory.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold, address(this));
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
      rewardRecipient,
      threshold
    );
    owrFactory.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold, address(this));

    recoveryAddress = address(0);

    // don't check deploy address
    vm.expectEmit(false, true, true, true);
    emit CreateOWRecipient(
      address(0xdead),
      address(this),
      recoveryAddress,
      principalRecipient,
      rewardRecipient,
      threshold
    );
    owrFactory.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold, address(this));
  }

  function testCannot_createWithInvalidRecipients() public {
    (principalRecipient, rewardRecipient, threshold) = generateTranches(1, 1);
    // eth
    vm.expectRevert(OptimisticWithdrawalRecipientV2Factory.Invalid__Recipients.selector);
    owrFactory.createOWRecipient(recoveryAddress, address(0), rewardRecipient, threshold, address(this));

    vm.expectRevert(OptimisticWithdrawalRecipientV2Factory.Invalid__Recipients.selector);
    owrFactory.createOWRecipient(recoveryAddress, address(0), address(0), threshold, address(this));

    vm.expectRevert(OptimisticWithdrawalRecipientV2Factory.Invalid__Recipients.selector);
    owrFactory.createOWRecipient(recoveryAddress, principalRecipient, address(0), threshold, address(this));
  }

  function testCannot_createWithInvalidThreshold() public {
    (principalRecipient, rewardRecipient) = generateTrancheRecipients(2);
    threshold = 0;

    vm.expectRevert(OptimisticWithdrawalRecipientV2Factory.Invalid__ZeroThreshold.selector);
    owrFactory.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold, address(this));

    vm.expectRevert(
      abi.encodeWithSelector(
        OptimisticWithdrawalRecipientV2Factory.Invalid__ThresholdTooLarge.selector,
        type(uint128).max
      )
    );
    owrFactory.createOWRecipient(
      recoveryAddress,
      principalRecipient,
      rewardRecipient,
      type(uint128).max,
      address(this)
    );
  }

  /// -----------------------------------------------------------------------
  /// Fuzzing Tests
  /// ----------------------------------------------------------------------

  function testFuzzCan_createOWRecipient(
    address _recoveryAddress,
    uint256 recipientsSeed,
    uint256 thresholdSeed
  ) public {
    recoveryAddress = _recoveryAddress;

    (principalRecipient, rewardRecipient, threshold) = generateTranches(recipientsSeed, thresholdSeed);

    vm.expectEmit(false, true, true, true);
    emit CreateOWRecipient(
      address(0xdead),
      address(this),
      recoveryAddress,
      principalRecipient,
      rewardRecipient,
      threshold
    );
    owrFactory.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold, address(this));
  }

  function testFuzzCannot_CreateWithZeroThreshold(uint256 _receipientSeed) public {
    threshold = 0;
    (principalRecipient, rewardRecipient) = generateTrancheRecipients(_receipientSeed);

    // eth
    vm.expectRevert(OptimisticWithdrawalRecipientV2Factory.Invalid__ZeroThreshold.selector);
    owrFactory.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold, address(this));
  }

  function testFuzzCannot_CreateWithLargeThreshold(uint256 _receipientSeed, uint256 _threshold) public {
    vm.assume(_threshold > type(uint96).max);

    threshold = _threshold;
    (principalRecipient, rewardRecipient) = generateTrancheRecipients(_receipientSeed);

    vm.expectRevert(
      abi.encodeWithSelector(OptimisticWithdrawalRecipientV2Factory.Invalid__ThresholdTooLarge.selector, _threshold)
    );
    owrFactory.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold, address(this));
  }
}
