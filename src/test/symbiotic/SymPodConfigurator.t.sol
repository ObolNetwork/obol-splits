// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import {SymPodConfigurator} from "src/symbiotic/SymPodConfigurator.sol";
import "forge-std/Test.sol";

contract SymPodConfiguratorTest is Test {

    error Unauthorized();

    SymPodConfigurator podConfigurator;

    address symPodConfiguratorOwner;

    function setUp() public {
        symPodConfiguratorOwner = makeAddr("symPodConfiguratorOwner");
        podConfigurator = new SymPodConfigurator(symPodConfiguratorOwner);
    }

    function test_CannotPauseCheckPointIfNotOwner() public {
        vm.expectRevert(Unauthorized.selector);
        podConfigurator.pauseCheckPoint();
    }

    function test_CanPauseCheckPoint() external {
        vm.prank(symPodConfiguratorOwner);
        podConfigurator.pauseCheckPoint();

        assertEq(
            podConfigurator.isCheckPointPaused(),
            true,
            "could not pause checkpoint"
        );
    }

    function test_CannotUnPauseCheckPointIfNotOwner() external {
        vm.expectRevert(Unauthorized.selector);
        podConfigurator.unpauseCheckPoint();
    }

    function test_CanUnPauseCheckPoint() external {
        vm.prank(symPodConfiguratorOwner);
        podConfigurator.pauseCheckPoint();

        vm.prank(symPodConfiguratorOwner);
        podConfigurator.unpauseCheckPoint();

        assertEq(
            podConfigurator.isCheckPointPaused(),
            false,
            "could not unpause checkpoint"
        );
    }

    function test_CannotPauseWithdrawalsIfNotOwner() public {
        vm.expectRevert(Unauthorized.selector);
        podConfigurator.pauseWithdrawals();
    }

    function test_CanPauseWithdrawals() external {
        vm.prank(symPodConfiguratorOwner);
        podConfigurator.pauseWithdrawals();

        assertEq(
            podConfigurator.isWithdrawalsPaused(),
            true,
            "could not pause withdrawals"
        );
    }

    function test_CannotUnPauseWithdrawalsIfNotOwner() external {
        vm.expectRevert(Unauthorized.selector);
        podConfigurator.unpauseWithdrawals();
    }

    function test_CanUnPauseWithdrawal() external {
        vm.prank(symPodConfiguratorOwner);
        podConfigurator.pauseWithdrawals();

        vm.prank(symPodConfiguratorOwner);
        podConfigurator.unpauseWithdrawals();

        assertEq(
            podConfigurator.isWithdrawalsPaused(),
            false,
            "could not unpause withdrawals"
        );
    }


}