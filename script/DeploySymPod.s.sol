// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {SymPodFactory} from "src/symbiotic/SymPodFactory.sol";
import {SymPod} from "src/symbiotic/SymPod.sol";
import {SymPodConfigurator} from "src/symbiotic/SymPodConfigurator.sol";
import {SymPodSlasher} from "src/symbiotic/SymPodSlasher.sol";
import {SymPodBeacon} from "src/symbiotic/SymPodBeacon.sol";

contract DeploySymPod is Script {
  uint256 BALANCE_DELTA_PERCENT = 10;
  address BEACON_ROOTS_ORACLE = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;
  // Holesky Deposit Contract 0x4242424242424242424242424242424242424242

  function run(address ethDepositContract, address configuratorOwner, address upgradesAdmin, uint256 withdrawalDelayPeriodSeconds) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");

    vm.startBroadcast(privKey);
    address symPodConfigurator = address(new SymPodConfigurator(configuratorOwner));
    address symPod = address(
      new SymPod(
        symPodConfigurator, ethDepositContract, BEACON_ROOTS_ORACLE, withdrawalDelayPeriodSeconds, BALANCE_DELTA_PERCENT
      )
    );
    address symPodBeacon = address(new SymPodBeacon(symPod, upgradesAdmin));
    address symPodFactory = address(new SymPodFactory(symPodBeacon));
    address symPodSlasher = address(new SymPodSlasher());

    vm.stopBroadcast();

    string memory symPodJsonKey = "symPodJsonKey";
    vm.serializeAddress(symPodJsonKey, "symPodConfigurator", symPodConfigurator);
    vm.serializeAddress(symPodJsonKey, "symPod", symPod);
    vm.serializeAddress(symPodJsonKey, "symPodBeacon", symPodBeacon);
    vm.serializeAddress(symPodJsonKey, "symPodSlasher", symPodSlasher);
    string memory finalJson = vm.serializeAddress(symPodJsonKey, "symPodFactory", symPodFactory);

    vm.writeJson(finalJson, "./sympod-deployment.json");
  }
}
