// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {OptimisticWithdrawalRecipient} from "src/owr/OptimisticWithdrawalRecipient.sol";
import {OptimisticWithdrawalRecipientFactory} from "src/owr/OptimisticWithdrawalRecipientFactory.sol";
import {MockERC20} from "../utils/mocks/MockERC20.sol";
import {OWRTestHelper} from "./OWRTestHelper.t.sol";
import {IENSReverseRegistrar} from "../../interfaces/external/IENSReverseRegistrar.sol";

contract OptimisticWithdrawalRecipientFactoryTest is OWRTestHelper, Test {
  event CreateOWRecipient(
    address indexed owr, address recoveryAddress, address principalRecipient, address rewardRecipient, uint256 threshold
  );

  address public ENS_REVERSE_REGISTRAR_GOERLI = 0x084b1c3C81545d370f3634392De611CaaBFf8148;

  OptimisticWithdrawalRecipientFactory owrFactoryModule;

  address public recoveryAddress;
  address public principalRecipient;
  address public rewardRecipient;
  uint256 public threshold;

  function setUp() public {
    vm.mockCall(
      ENS_REVERSE_REGISTRAR_GOERLI,
      abi.encodeWithSelector(IENSReverseRegistrar.setName.selector),
      bytes.concat(bytes32(0))
    );
    vm.mockCall(
      ENS_REVERSE_REGISTRAR_GOERLI,
      abi.encodeWithSelector(IENSReverseRegistrar.claim.selector),
      bytes.concat(bytes32(0))
    );

    owrFactoryModule =
      new OptimisticWithdrawalRecipientFactory("demo.obol.eth", ENS_REVERSE_REGISTRAR_GOERLI, address(this));

    recoveryAddress = makeAddr("recoveryAddress");
    (principalRecipient, rewardRecipient) = generateTrancheRecipients(10);
    threshold = ETH_STAKE;
  }

  function testCan_createOWRecipient() public {
    owrFactoryModule.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold);

    recoveryAddress = address(0);
    owrFactoryModule.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold);
  }

  function testCan_emitOnCreate() public {
    // don't check deploy address
    vm.expectEmit(false, true, true, true);

    emit CreateOWRecipient(address(0xdead), recoveryAddress, principalRecipient, rewardRecipient, threshold);
    owrFactoryModule.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold);

    recoveryAddress = address(0);

    // don't check deploy address
    vm.expectEmit(false, true, true, true);
    emit CreateOWRecipient(address(0xdead), recoveryAddress, principalRecipient, rewardRecipient, threshold);
    owrFactoryModule.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold);
  }

  function testCannot_createWithInvalidRecipients() public {
    (principalRecipient, rewardRecipient, threshold) = generateTranches(1, 1);
    // eth
    vm.expectRevert(OptimisticWithdrawalRecipientFactory.Invalid__Recipients.selector);
    owrFactoryModule.createOWRecipient(recoveryAddress, address(0), rewardRecipient, threshold);

    vm.expectRevert(OptimisticWithdrawalRecipientFactory.Invalid__Recipients.selector);
    owrFactoryModule.createOWRecipient(recoveryAddress, address(0), address(0), threshold);

    vm.expectRevert(OptimisticWithdrawalRecipientFactory.Invalid__Recipients.selector);
    owrFactoryModule.createOWRecipient(recoveryAddress, principalRecipient, address(0), threshold);
  }

  function testCannot_createWithInvalidThreshold() public {
    (principalRecipient, rewardRecipient) = generateTrancheRecipients(2);
    threshold = 0;

    vm.expectRevert(OptimisticWithdrawalRecipientFactory.Invalid__ZeroThreshold.selector);
    owrFactoryModule.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold);

    vm.expectRevert(
      abi.encodeWithSelector(
        OptimisticWithdrawalRecipientFactory.Invalid__ThresholdTooLarge.selector, type(uint128).max
      )
    );
    owrFactoryModule.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, type(uint128).max);
  }

  /// -----------------------------------------------------------------------
  /// Fuzzing Tests
  /// ----------------------------------------------------------------------

  function testFuzzCan_createOWRecipient(address _recoveryAddress, uint256 recipientsSeed, uint256 thresholdSeed)
    public
  {
    recoveryAddress = _recoveryAddress;

    (principalRecipient, rewardRecipient, threshold) = generateTranches(recipientsSeed, thresholdSeed);

    vm.expectEmit(false, true, true, true);
    emit CreateOWRecipient(address(0xdead), recoveryAddress, principalRecipient, rewardRecipient, threshold);
    owrFactoryModule.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold);
  }

  function testFuzzCannot_CreateWithZeroThreshold(uint256 _receipientSeed) public {
    threshold = 0;
    (principalRecipient, rewardRecipient) = generateTrancheRecipients(_receipientSeed);

    // eth
    vm.expectRevert(OptimisticWithdrawalRecipientFactory.Invalid__ZeroThreshold.selector);
    owrFactoryModule.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold);
  }

  function testFuzzCannot_CreateWithLargeThreshold(uint256 _receipientSeed, uint256 _threshold) public {
    vm.assume(_threshold > type(uint96).max);

    threshold = _threshold;
    (principalRecipient, rewardRecipient) = generateTrancheRecipients(_receipientSeed);

    vm.expectRevert(
      abi.encodeWithSelector(OptimisticWithdrawalRecipientFactory.Invalid__ThresholdTooLarge.selector, _threshold)
    );
    owrFactoryModule.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold);
  }
}
