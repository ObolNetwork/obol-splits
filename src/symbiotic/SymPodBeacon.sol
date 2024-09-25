// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {UpgradeableBeacon} from "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";
import {SymPod} from "./Sympod.sol";

/// @title SymPod
/// @author Obol
/// @notice Capsule beacon proxy beacon
contract SymPodBeacon is UpgradeableBeacon {
  constructor(address symPodImplementation, address owner) UpgradeableBeacon(symPodImplementation) {
    require(owner != address(0), "invalid ownwer");
    require(symPodImplementation != address(0), "invalid implementation");

    _transferOwnership(owner);
  }
}
