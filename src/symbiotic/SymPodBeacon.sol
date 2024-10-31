// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {UpgradeableBeacon} from "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";

/// @title SymPod
/// @author Obol
/// @notice Capsule beacon proxy beacon
contract SymPodBeacon is UpgradeableBeacon {
  constructor(address symPodImplementation, address _owner) UpgradeableBeacon(symPodImplementation) {
    require(_owner != address(0), "invalid owner");
    require(symPodImplementation != address(0), "invalid implementation");

    _transferOwnership(_owner);
  }
}
