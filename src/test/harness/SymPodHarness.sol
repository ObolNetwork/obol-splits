// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;
import {SymPod} from "src/symbiotic/SymPod.sol";

contract SymPodHarness is SymPod {

    constructor(
        address _symPodConfigurator,
        address _eth2DepositContract,
        address _beaconRootsOracle,
        uint256 _withdrawDelayPeriod
    ) SymPod(
        _symPodConfigurator,
        _eth2DepositContract,
        _beaconRootsOracle,
        _withdrawDelayPeriod
    ) {
    }

    function setNumberOfValidators(uint256 num) external {
        numberOfActiveValidators = uint64(num);
    }
}
