// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ObolRocketPoolRecipientFactory} from "src/rocket-pool/ObolRocketPoolRecipientFactory.sol";
import {MockERC20} from "../utils/mocks/MockERC20.sol";
import {IENSReverseRegistrar} from "../../interfaces/IENSReverseRegistrar.sol";
import {RocketPoolTestHelper} from "./RocketPoolTestHelper.t.sol";
import {RPStorageMock} from "./mocks/RPStorageMock.sol";

contract ObolRocketPoolRecipientFactoryTest is RocketPoolTestHelper, Test {
  event CreateObolRocketPoolRecipient(
    address indexed rp,
    address rpStorage,
    address recoveryAddress,
    address principalRecipient,
    address rewardRecipient,
    uint256 threshold
  );

  address public ENS_REVERSE_REGISTRAR_GOERLI = 0x084b1c3C81545d370f3634392De611CaaBFf8148;

  ObolRocketPoolRecipientFactory rpRecipientFactoryModule;
  MockERC20 mERC20;
  RPStorageMock rpStorage;
  address public recoveryAddress;
  address public principalRecipient;
  address public rewardRecipient;
  uint256 public threshold;

  function setUp() public {
    mERC20 = new MockERC20("Test Token", "TOK", 18);
    mERC20.mint(type(uint256).max);

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

    rpStorage = new RPStorageMock();
    rpRecipientFactoryModule = new ObolRocketPoolRecipientFactory(
      address(rpStorage), "demo.obol.eth", ENS_REVERSE_REGISTRAR_GOERLI, address(this)
    );

    recoveryAddress = makeAddr("recoveryAddress");
    (principalRecipient, rewardRecipient) = generateTrancheRecipients(10);
    threshold = ETH_STAKE;
  }

  function testCan_createRocketPoolRecipient() public {
    rpRecipientFactoryModule.createObolRocketPoolRecipient(
      recoveryAddress, principalRecipient, rewardRecipient, threshold
    );

    recoveryAddress = address(0);
    rpRecipientFactoryModule.createObolRocketPoolRecipient(
      recoveryAddress, principalRecipient, rewardRecipient, threshold
    );
  }

  function testCan_emitOnCreate() public {
    // don't check deploy address
    vm.expectEmit(false, true, true, true);
    emit CreateObolRocketPoolRecipient(
      address(0xdead), address(rpStorage), recoveryAddress, principalRecipient, rewardRecipient, threshold
    );
    rpRecipientFactoryModule.createObolRocketPoolRecipient(
      recoveryAddress, principalRecipient, rewardRecipient, threshold
    );

    recoveryAddress = address(0);
    // don't check deploy address
    vm.expectEmit(false, true, true, true);
    emit CreateObolRocketPoolRecipient(
      address(0xdead), address(rpStorage), recoveryAddress, principalRecipient, rewardRecipient, threshold
    );
    rpRecipientFactoryModule.createObolRocketPoolRecipient(
      recoveryAddress, principalRecipient, rewardRecipient, threshold
    );
  }

  function testCannot_createWithInvalidRecipients() public {
    (principalRecipient, rewardRecipient, threshold) = generateTranches(1, 1);
    // eth
    vm.expectRevert(ObolRocketPoolRecipientFactory.Invalid__Recipients.selector);
    rpRecipientFactoryModule.createObolRocketPoolRecipient(recoveryAddress, address(0), rewardRecipient, threshold);

    vm.expectRevert(ObolRocketPoolRecipientFactory.Invalid__Recipients.selector);
    rpRecipientFactoryModule.createObolRocketPoolRecipient(recoveryAddress, address(0), address(0), threshold);

    vm.expectRevert(ObolRocketPoolRecipientFactory.Invalid__Recipients.selector);
    rpRecipientFactoryModule.createObolRocketPoolRecipient(recoveryAddress, principalRecipient, address(0), threshold);
  }

  function testCannot_createWithInvalidThreshold() public {
    (principalRecipient, rewardRecipient) = generateTrancheRecipients(2);
    threshold = 0;

    vm.expectRevert(ObolRocketPoolRecipientFactory.Invalid__ZeroThreshold.selector);
    rpRecipientFactoryModule.createObolRocketPoolRecipient(
      recoveryAddress, principalRecipient, rewardRecipient, threshold
    );
  }

  /// -----------------------------------------------------------------------
  /// Fuzzing Tests
  /// ----------------------------------------------------------------------

  function testFuzzCan_createRocketPoolRecipient(
    address _recoveryAddress,
    uint256 recipientsSeed,
    uint256 thresholdSeed
  ) public {
    recoveryAddress = _recoveryAddress;

    (principalRecipient, rewardRecipient, threshold) = generateTranches(recipientsSeed, thresholdSeed);

    vm.expectEmit(false, true, true, true);
    emit CreateObolRocketPoolRecipient(
      address(0xdead), address(rpStorage), recoveryAddress, principalRecipient, rewardRecipient, threshold
    );
    rpRecipientFactoryModule.createObolRocketPoolRecipient(
      recoveryAddress, principalRecipient, rewardRecipient, threshold
    );
  }

  function testFuzzCannot_CreateWithZeroThreshold(uint256 _receipientSeed) public {
    threshold = 0;
    (principalRecipient, rewardRecipient) = generateTrancheRecipients(_receipientSeed);

    // eth
    vm.expectRevert(ObolRocketPoolRecipientFactory.Invalid__ZeroThreshold.selector);
    rpRecipientFactoryModule.createObolRocketPoolRecipient(
      recoveryAddress, principalRecipient, rewardRecipient, threshold
    );
  }

  function testFuzzCannot_CreateWithLargeThreshold(uint256 _receipientSeed, uint256 _threshold) public {
    vm.assume(_threshold > type(uint96).max);

    threshold = _threshold;
    (principalRecipient, rewardRecipient) = generateTrancheRecipients(_receipientSeed);

    vm.expectRevert(
      abi.encodeWithSelector(ObolRocketPoolRecipientFactory.Invalid__ThresholdTooLarge.selector, _threshold)
    );
    rpRecipientFactoryModule.createObolRocketPoolRecipient(
      recoveryAddress, principalRecipient, rewardRecipient, threshold
    );
  }
}
