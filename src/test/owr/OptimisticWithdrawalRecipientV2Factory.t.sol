// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {OptimisticWithdrawalRecipientV2} from "src/owr/OptimisticWithdrawalRecipientV2.sol";
import {OptimisticWithdrawalRecipientV2Factory} from "src/owr/OptimisticWithdrawalRecipientV2Factory.sol";
import {MockERC20} from "../utils/mocks/MockERC20.sol";
import {OWRTestHelper} from "../owr/OWRTestHelper.t.sol";
import {ExecutionLayerWithdrawalSystemContractMock} from "./pectra/ExecutionLayerWithdrawalSystemContractMock.sol";
import {IENSReverseRegistrar} from "../../interfaces/IENSReverseRegistrar.sol";

contract OptimisticWithdrawalRecipientV2FactoryTest is OWRTestHelper, Test {
  event CreateOWRecipient(
    address indexed owr, address indexed owner, address recoveryAddress, address principalRecipient, address rewardRecipient, uint256 threshold
  );

  address public ENS_REVERSE_REGISTRAR_GOERLI = 0x084b1c3C81545d370f3634392De611CaaBFf8148;

  ExecutionLayerWithdrawalSystemContractMock withdrawalMock;
  OptimisticWithdrawalRecipientV2Factory owrFactoryModule;

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


    withdrawalMock = new ExecutionLayerWithdrawalSystemContractMock();
    owrFactoryModule =
      new OptimisticWithdrawalRecipientV2Factory(
      "demo.obol.eth", ENS_REVERSE_REGISTRAR_GOERLI, address(this), address(withdrawalMock), address(withdrawalMock), address(withdrawalMock)
    );
    recoveryAddress = makeAddr("recoveryAddress");
    (principalRecipient, rewardRecipient) = generateTrancheRecipients(10);
    threshold = ETH_STAKE;
  }

  function testCan_createOWRecipient() public {
    owrFactoryModule.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold, address(this));

    recoveryAddress = address(0);
    owrFactoryModule.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold, address(this));
  }

  function testCan_emitOnCreate() public {
    // don't check deploy address
    vm.expectEmit(false, true, true, true);

    emit CreateOWRecipient(address(0xdead), address(this), recoveryAddress, principalRecipient, rewardRecipient, threshold);
    owrFactoryModule.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold, address(this));

    recoveryAddress = address(0);

    // don't check deploy address
    vm.expectEmit(false, true, true, true);
    emit CreateOWRecipient(address(0xdead), address(this), recoveryAddress, principalRecipient, rewardRecipient, threshold);
    owrFactoryModule.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold, address(this));
  }

  function testCannot_createWithInvalidRecipients() public {
    (principalRecipient, rewardRecipient, threshold) = generateTranches(1, 1);
    // eth
    vm.expectRevert(OptimisticWithdrawalRecipientV2Factory.Invalid__Recipients.selector);
    owrFactoryModule.createOWRecipient(recoveryAddress, address(0), rewardRecipient, threshold, address(this));

    vm.expectRevert(OptimisticWithdrawalRecipientV2Factory.Invalid__Recipients.selector);
    owrFactoryModule.createOWRecipient(recoveryAddress, address(0), address(0), threshold, address(this));

    vm.expectRevert(OptimisticWithdrawalRecipientV2Factory.Invalid__Recipients.selector);
    owrFactoryModule.createOWRecipient(recoveryAddress, principalRecipient, address(0), threshold, address(this));
  }

  function testCannot_createWithInvalidThreshold() public {
    (principalRecipient, rewardRecipient) = generateTrancheRecipients(2);
    threshold = 0;

    vm.expectRevert(OptimisticWithdrawalRecipientV2Factory.Invalid__ZeroThreshold.selector);
    owrFactoryModule.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold, address(this));

    vm.expectRevert(
      abi.encodeWithSelector(
        OptimisticWithdrawalRecipientV2Factory.Invalid__ThresholdTooLarge.selector, type(uint128).max
      )
    );
    owrFactoryModule.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, type(uint128).max, address(this));
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
    emit CreateOWRecipient(address(0xdead), address(this), recoveryAddress, principalRecipient, rewardRecipient, threshold);
    owrFactoryModule.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold, address(this));
  }

  function testFuzzCannot_CreateWithZeroThreshold(uint256 _receipientSeed) public {
    threshold = 0;
    (principalRecipient, rewardRecipient) = generateTrancheRecipients(_receipientSeed);

    // eth
    vm.expectRevert(OptimisticWithdrawalRecipientV2Factory.Invalid__ZeroThreshold.selector);
    owrFactoryModule.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold, address(this));
  }

  function testFuzzCannot_CreateWithLargeThreshold(uint256 _receipientSeed, uint256 _threshold) public {
    vm.assume(_threshold > type(uint96).max);

    threshold = _threshold;
    (principalRecipient, rewardRecipient) = generateTrancheRecipients(_receipientSeed);

    vm.expectRevert(
      abi.encodeWithSelector(OptimisticWithdrawalRecipientV2Factory.Invalid__ThresholdTooLarge.selector, _threshold)
    );
    owrFactoryModule.createOWRecipient(recoveryAddress, principalRecipient, rewardRecipient, threshold, address(this));
  }
}
