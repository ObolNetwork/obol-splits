// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;
import "forge-std/Test.sol";
import {Merkle} from "src/libraries/Merkle.sol";
import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";
import { SymPodProofParser } from "./SymPodProofParser.sol";
import {BeaconChainProofHarness} from "src/test/harness/BeaconChainProofHarness.sol";

abstract contract BaseBeaconChainProofTest is Test {
    SymPodProofParser parser;
    BeaconChainProofHarness beaconChainProofHarness;

    function setUp() public virtual {
        parser = new SymPodProofParser();
        beaconChainProofHarness = new BeaconChainProofHarness();
    }
}

contract BeaconChainProofTest__ValidatorRootAgainstBlockRoot is BaseBeaconChainProofTest {
    function setUp() override public {
        super.setUp();
        string memory filePath = "";
        parser.setJSONPath(filePath);
    }
}

// contract BeaconChainProofTest__