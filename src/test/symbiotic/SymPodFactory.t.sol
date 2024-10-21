// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {SymPodFactory} from "src/symbiotic/SymPodFactory.sol";
import {SymPodBeacon} from "src/symbiotic/SymPodBeacon.sol";
import {SymPod} from "src/symbiotic/SymPod.sol";
import {SymPodConfigurator} from "src/symbiotic/SymPodConfigurator.sol";
import {MockBeaconRootOracle} from "src/test/utils/mocks/MockBeaconRootOracle.sol";
import {MockETH2Deposit} from "src/test/utils/mocks/MockETH2Deposit.sol";
import "forge-std/Test.sol";

contract SymPodFactoryTest is Test {
  string podName = "obolTest";
  string podSymbol = "OTK";

  SymPod podImplementation;
  SymPodFactory podFactory;
  SymPodBeacon podBeacon;
  SymPodConfigurator podConfigurator;

  address symPodConfiguratorOwner;
  address podAdmin;
  address withdrawalAddress;
  address recoveryRecipient;
  address slasher;

  uint256 WITHDRAWAL_DELAY_PERIOD = 2 seconds;
  uint256 BALANCE_DELTA = 10;
  address MOCK_ETH2_DEPOSIT_CONTRACT;

  function setUp() public {
    symPodConfiguratorOwner = makeAddr("symPodConfiguratorOwner");
    podAdmin = makeAddr("podAdmin");
    withdrawalAddress = makeAddr("withdrawalAddress");
    recoveryRecipient = makeAddr("recoveryRecipient");
    slasher = makeAddr("slasher");
    MOCK_ETH2_DEPOSIT_CONTRACT = address(new MockETH2Deposit());

    podConfigurator = new SymPodConfigurator(symPodConfiguratorOwner);
    MockBeaconRootOracle beaconRootOracle = new MockBeaconRootOracle();

    podImplementation = new SymPod(
      address(podConfigurator),
      MOCK_ETH2_DEPOSIT_CONTRACT,
      address(beaconRootOracle),
      WITHDRAWAL_DELAY_PERIOD,
      BALANCE_DELTA
    );
    podBeacon = new SymPodBeacon(address(podImplementation), symPodConfiguratorOwner);

    podFactory = new SymPodFactory(address(podBeacon));
  }

  function test_CanCreateSymPod() public {
    SymPod createdPod = SymPod(
      payable(podFactory.createSymPod(podName, podSymbol, slasher, podAdmin, withdrawalAddress, recoveryRecipient))
    );

    assertEq(createdPod.name(), podName, "incorrect name");

    assertEq(createdPod.symbol(), podSymbol, "incorrect symbol");
  }

  function test_PredictPodAddress() public {
    address predictedAddress =
      podFactory.predictSymPodAddress(podName, podSymbol, slasher, podAdmin, withdrawalAddress, recoveryRecipient);
    address createdPod =
      podFactory.createSymPod(podName, podSymbol, slasher, podAdmin, withdrawalAddress, recoveryRecipient);
    assertEq(predictedAddress, createdPod, "predicted address not equal to created addresss");
  }
}
