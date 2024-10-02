// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import {SymPodFactory} from "src/symbiotic/SymPodFactory.sol";
import {SymPodBeacon} from "src/symbiotic/SymPodBeacon.sol";
import {SymPod, ISymPod} from "src/symbiotic/SymPod.sol";
import {SymPodConfigurator} from "src/symbiotic/SymPodConfigurator.sol";
import {MockBeaconRootOracle} from "src/test/utils/mocks/MockBeaconRootOracle.sol";
import {MockETH2Deposit} from "src/test/utils/mocks/MockETH2Deposit.sol";
import {SymPodHarness} from "src/test/harness/SymPodHarness.sol";

import "forge-std/Test.sol";

contract BaseSymPodTest is Test {
    string podName = "obolTest";
    string podSymbol = "OTK";

    SymPod podImplementation;
    SymPod createdPod;
    SymPodFactory podFactory;
    SymPodBeacon podBeacon;
    SymPodConfigurator podConfigurator;
    MockBeaconRootOracle beaconRootOracle;

    address symPodConfiguratorOwner;
    address podAdmin;
    address withdrawalAddress;
    address recoveryRecipient;

    uint256 WITHDRAWAL_DELAY_PERIOD = 2 seconds;
    address MOCK_ETH2_DEPOSIT_CONTRACT;

    bytes32 blockRoot;

    function setUp() public virtual {
        symPodConfiguratorOwner = makeAddr("symPodConfiguratorOwner");
        podAdmin = makeAddr("podAdmin");
        withdrawalAddress = makeAddr("withdrawalAddress");
        recoveryRecipient = makeAddr("recoveryRecipient");
        MOCK_ETH2_DEPOSIT_CONTRACT = address(new MockETH2Deposit());

        podConfigurator = new SymPodConfigurator(symPodConfiguratorOwner);
        beaconRootOracle = new MockBeaconRootOracle();
        
        podImplementation = new SymPod(
            address(podConfigurator),
            MOCK_ETH2_DEPOSIT_CONTRACT,
            address(beaconRootOracle),
            WITHDRAWAL_DELAY_PERIOD
        );
        podBeacon = new SymPodBeacon(
            address(podImplementation),
            symPodConfiguratorOwner
        );

        podFactory = new SymPodFactory(address(podBeacon));

        createdPod = SymPod(payable(podFactory.createSymPod(
            podName,
            podSymbol,
            podAdmin,
            withdrawalAddress,
            recoveryRecipient
        )));

        // set roots on oracle
        blockRoot = bytes32(uint256(1));
        beaconRootOracle.setBlockRoot(uint64(block.timestamp), blockRoot);
    }
}

contract BaseSymPodHarnessTest is BaseSymPodTest {
    SymPodHarness podHarnessImplementation;
    SymPodHarness createdHarnessPod;
    SymPodFactory podHarnessFactory;
    SymPodBeacon podHarnessBeacon;

    function setUp() public override {
        super.setUp();

        podHarnessImplementation = new SymPodHarness(
            address(podConfigurator),
            MOCK_ETH2_DEPOSIT_CONTRACT,
            address(beaconRootOracle),
            WITHDRAWAL_DELAY_PERIOD
        );
        podHarnessBeacon = new SymPodBeacon(
            address(podHarnessImplementation),
            symPodConfiguratorOwner
        );

        podHarnessFactory = new SymPodFactory(address(podHarnessBeacon));

        createdHarnessPod = SymPodHarness(payable(podHarnessFactory.createSymPod(
            podName,
            podSymbol,
            podAdmin,
            withdrawalAddress,
            recoveryRecipient
        )));
    }
}

contract SymPod__Stake is BaseSymPodTest {    
    function test_CanStake() public {
        bytes memory pubkey = bytes("setup");
        bytes memory sig = bytes("sig");
        bytes32 depositDataRoot = keccak256(pubkey);

        createdPod.stake{value: 1 ether}(
            pubkey,
            sig,
            depositDataRoot
        );
    }
}


contract SymPod__StartCheckPoint is BaseSymPodHarnessTest {
    error SymPod__Unauthorized();
    event CheckpointCreated(
        uint256 timestamp,
        bytes32 beaconBlockRoot,
        uint256 proofsRemaining
    );

    function test__CannotStartCheckPointIfNotAdmin() public {
        vm.expectRevert(ISymPod.SymPod__Unauthorized.selector);
        createdPod.startCheckpoint(false);
    }

    function test_CannotStartCheckPointIfPodBalanceIsZero() public {
        vm.prank(podAdmin);
        vm.expectRevert(ISymPod.SymPod__RevertIfNoBalance.selector);
        createdPod.startCheckpoint(true);
    }

    function test_CannotStartCheckpointIfPaused() public {
        vm.prank(symPodConfiguratorOwner);
        podConfigurator.pauseCheckPoint();

        vm.prank(podAdmin);
        vm.expectRevert(ISymPod.SymPod__CheckPointPaused.selector);
        createdPod.startCheckpoint(true);
    }

    function test_CannotDoublyStartCheckpointIfPaused() public {
        // sets the number of validators
        createdHarnessPod.setNumberOfValidators(1);

        vm.prank(podAdmin);
        createdHarnessPod.startCheckpoint(false);

        vm.prank(podAdmin);
        vm.expectRevert(ISymPod.SymPod__CompletePreviousCheckPoint.selector);
        createdHarnessPod.startCheckpoint(false);
    }

    function test_CanStartCheckPointIfPodBalanceIsZero() public {
        uint256 numValidators = 1;
        // sets the number of validators
        createdHarnessPod.setNumberOfValidators(numValidators);

        vm.expectEmit(true, true, true, true);
        emit CheckpointCreated(block.timestamp, blockRoot, numValidators);

        vm.prank(podAdmin);
        createdHarnessPod.startCheckpoint(false);

        // confirm details here
        assertEq(
            createdHarnessPod.currentCheckPointTimestamp(),
            block.timestamp,
            "invalid current checkpoint timestamp"
        );

        (
            bytes32 beaconBlockRoot,
            uint24 proofsRemaining,
            uint64 podBalanceGwei,
            uint40 currentTimestamp,
            int128 balanceDeltasGwei
        ) = createdHarnessPod.currentCheckPoint();

        assertEq(
            beaconBlockRoot,
            blockRoot,
            "invalid block root"
        );

        assertEq(
            proofsRemaining,
            numValidators,
            "invalid number validators"
        );

        assertEq(
            currentTimestamp,
            block.timestamp,
            "invalid timestamp"
        );

        assertEq(
            balanceDeltasGwei,
            0,
            "invalid delta"
        );
    }
}

