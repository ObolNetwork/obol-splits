// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {MockERC20} from "src/test/utils/mocks/MockERC20.sol";
import {SimpleETHContributionVault} from "src/safe-modules/SimpleETHContributionVault.sol";


contract ETHVaultSafeModuleTest is Test {
    error CannotRageQuit();
    error Unauthorized(address user);

    event Deposit(address to, uint256 amount);
    event DepositValidator(
        bytes[] pubkeys,
        bytes[] withdrawal_credentials,
        bytes[] signatures,
        bytes32[] deposit_data_roots
    );
    event RageQuit(address to, uint256 amount);
    event RescueFunds(uint256 amount);

    address constant ETH_DEPOSIT_CONTRACT = address(0x0);
    uint256 internal constant ETH_STAKE = 32 ether;
    
    SimpleETHContributionVault contributionVault;
    
    address safe;
    address user1;
    address user2;
    address user3;
    MockERC20 mERC20;

    function setUp() public {
        safe = makeAddr("safe");
        contributionVault = new SimpleETHContributionVault(
            safe,
            ETH_DEPOSIT_CONTRACT
        );
        
        mERC20 = new MockERC20("Test Token", "TOK", 18);
        mERC20.mint(type(uint256).max);
    }

    function test_deposit() external {
        vm.deal(user1, ETH_STAKE);
        
        vm.expectEmit(false, false, false, true);
        emit Deposit(user1, ETH_STAKE);

        vm.prank(user1);
        payable(contributionVault).transfer(ETH_STAKE);

        assertEq(
            contributionVault.userBalances(user1),
            ETH_STAKE,
            "failed to credit user balance"
        );
    }

    function testFuzz_deposit(
        address user,
        uint256 amount
    ) external {
        vm.deal(user, amount);

        vm.expectEmit(false, false, false, true);

        vm.prank(user);
        payable(contributionVault).transfer(amount);

        assertEq(
            contributionVault.userBalances(user),
            amount
        );
    }
    
    function test_rageQuit() external {
        vm.deal(user1, ETH_STAKE);

        vm.prank(user1);
        payable(contributionVault).transfer(ETH_STAKE);

        vm.expectEmit(false, false, false, true);
        emit RageQuit(user1, ETH_STAKE);

        contributionVault.rageQuit(user1, ETH_STAKE);
    }

    function testFuzz_rageQuit(
        address user,
        uint256 amount
    ) external {
        vm.deal(user, amount);

        vm.prank(user);
        payable(contributionVault).transfer(amount);

        vm.expectEmit(false, false, false, true);
        emit RageQuit(user, amount);

        contributionVault.rageQuit(user, amount);
    }

    function test_cannotRageQuitAfterDeposit() external {
        vm.deal(user1, ETH_STAKE);

        vm.prank(user1);
        payable(contributionVault).transfer(ETH_STAKE);

        bytes[] memory pubkeys = new bytes[](1);
        pubkeys[0] = bytes("");
        bytes[] memory withdrawal_credentials = new bytes[](1);
        withdrawal_credentials[0] = bytes("");
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = bytes("");
        bytes32[] memory deposit_data_roots = new bytes32[](1);
        deposit_data_roots[0] = bytes32(0);

        contributionVault.depositValidator(
            pubkeys,
            withdrawal_credentials,
            signatures,
            deposit_data_roots
        );

        vm.expectRevert(CannotRageQuit.selector);
        contributionVault.rageQuit(
            user1,
            ETH_STAKE
        );
    }

    function test_depositValidator() external {
        vm.deal(user1, ETH_STAKE);
        vm.prank(user1);
        payable(contributionVault).transfer(ETH_STAKE);

        (
            bytes[] memory pubkeys,
            bytes[] memory withdrawal_credentials,
            bytes[] memory signatures,
            bytes32[] memory deposit_data_roots
        ) = getETHValidatorData();

        vm.prank(safe);
        contributionVault.depositValidator(
            pubkeys,
            withdrawal_credentials,
            signatures,
            deposit_data_roots
        );
    }

    function test_OnlySafeDepositValidator() external {
        (
            bytes[] memory pubkeys,
            bytes[] memory withdrawal_credentials,
            bytes[] memory signatures,
            bytes32[] memory deposit_data_roots
        ) = getETHValidatorData();

        vm.expectRevert(
            abi.encodeWithSelector(Unauthorized.selector, address(this))
        );
        contributionVault.depositValidator(
            pubkeys,
            withdrawal_credentials,
            signatures,
            deposit_data_roots
        );
    }

    function test_rescueFunds() external {
        uint256 amount = 1 ether;
        mERC20.transfer(address(contributionVault), amount);

        vm.expectEmit(false, false, false, true);
        emit RescueFunds(amount);
        
        contributionVault.rescueFunds(address(mERC20), amount);
    }

    function testFuzz_rescueFundETH(
        uint256 amount
    ) external {
        mERC20.transfer(address(contributionVault), amount);
        vm.expectEmit(false, false, false, true);
        emit RescueFunds(amount);
        
        contributionVault.rescueFunds(address(mERC20), amount);
    }
}

function getETHValidatorData() pure returns (
    bytes[] memory pubkeys,
    bytes[] memory withdrawal_credentials,
    bytes[] memory signatures,
    bytes32[] memory deposit_data_roots
) {

    pubkeys = new bytes[](1);
    pubkeys[0] = bytes("");

    withdrawal_credentials = new bytes[](1);
    withdrawal_credentials[0] = bytes("");

    signatures = new bytes[](1);
    signatures[0] = bytes("");
    
    deposit_data_roots = new bytes32[](1);
    deposit_data_roots[0] = bytes32(0);
}