// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import {UpgradeableBeacon} from "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";
import {ObolCapsule} from "./ObolCapsule.sol";

/// @title ObolCapsule
/// @author Obol
/// @notice Capsule beacon proxy beacon
contract ObolCapsuleBeacon is UpgradeableBeacon {
    constructor(address capsuleImplementation, address owner) UpgradeableBeacon(capsuleImplementation){
        require(owner != address(0), "invalid ownwer");
        require(capsuleImplementation != address(0), "invalid implementation");

        _transferOwnership(owner);
    }
}
