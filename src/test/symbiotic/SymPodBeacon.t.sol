// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import "forge-std/Test.sol";
import {SymPodBeacon} from "src/symbiotic/SymPodBeacon.sol";
import {MockBeaconRootOracle} from "src/test/utils/mocks/MockBeaconRootOracle.sol";

contract SymPodBeaconTest is Test {

    SymPodBeacon symPodBeacon;
    address symPodImplementation;
    address newSymPodImpl;
    address owner;
    address newOwner;

    function setUp() public {
        symPodImplementation = address(new MockBeaconRootOracle());
        newSymPodImpl = address(new MockBeaconRootOracle());
        owner = makeAddr("owner");
        newOwner = makeAddr("newOwner");

        symPodBeacon = new SymPodBeacon(
            symPodImplementation,
            owner
        );
    }

    function test_CannotCreateWithInvalidOwner() external {
        vm.expectRevert();
        new SymPodBeacon(
            symPodImplementation,
            address(0)
        );
    }
    
    function test_CannotCreateWithInvalidImpl() external {
        vm.expectRevert();
        new SymPodBeacon(
            address(0),
            owner
        );
    }

    function test_CannotUpgradeToIfNotOwner() external {
        vm.expectRevert();
        symPodBeacon.upgradeTo(newSymPodImpl);
    }

    function test_UpgradeTo() external {
        vm.prank(owner);
        symPodBeacon.upgradeTo(newSymPodImpl);

        assertEq(
            symPodBeacon.implementation(),
            newSymPodImpl,
            "could not upgrade implementation"
        );
    }

    function test_Owner() external {
        assertEq(
            symPodBeacon.owner(),
            owner,
            "invalid owner address"
        );
    }

    function test_CannotTransferOwnershipIfNotOwner() external {
        vm.expectRevert();
        symPodBeacon.transferOwnership(newOwner);
    }

    function test_transferOwnership() external {
        vm.prank(owner);
        symPodBeacon.transferOwnership(newOwner);

        assertEq(
            symPodBeacon.owner(),
            newOwner,
            "Invalid new owner"
        );
    }

    function test_CannotRenounceOwnershipIfNotOwner() external {
        vm.expectRevert();
        symPodBeacon.renounceOwnership();
    }

    function test_renounceOwnership() external {
        vm.prank(owner);
        symPodBeacon.renounceOwnership();

        assertEq(
            symPodBeacon.owner(),
            address(0),
            "could not renounce ownership"
        );
    }

    function test_implementation() external {
        assertEq(
            symPodBeacon.implementation(),
            symPodImplementation,
            "invalid implementation"
        );
    }

}