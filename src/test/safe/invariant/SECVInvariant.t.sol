// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;
import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {SimpleETHContributionVault} from "src/safe-modules/SimpleETHContributionVault.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

contract MockDepositContract {
    event Deposit (
        bytes[] pubkeys,
        bytes[] withdrawal_credentials,
        bytes[] signatures,
        bytes32[] deposit_data_roots
    );
    function depositValidator(
        bytes[] calldata,
        bytes[] calldata,
        bytes[] calldata,
        bytes32[] calldata
    ) external payable {}
}

contract SECVHandler is CommonBase, StdCheats, StdUtils {
    SimpleETHContributionVault public contributionVault;

    uint256 public constant ETH_SUPPLY = 100_000 ether;

    uint256 public ghost_depositSum;
    uint256 public ghost_rageQuitSum;

    receive() external payable {}

    constructor(SimpleETHContributionVault vault) {
        contributionVault = vault;
        deal(address(this), ETH_SUPPLY);
    }

    function deposit(uint256 amount) external payable {
        amount = bound(amount, 0, address(this).balance);
        (bool _success,) = payable(contributionVault).call{value: amount}("");
        assert(_success);

        ghost_depositSum += amount;

    }

    function rageQuit(uint256 amount) external payable {
        amount = bound(amount, 0 , contributionVault.userBalances(address(this)));
        contributionVault.rageQuit(address(this), amount);

        ghost_rageQuitSum += amount;
    }
}

contract SECVInvariant is Test {

    MockDepositContract public mockDepositContract;
    SimpleETHContributionVault public contributionVault;
    SECVHandler public handler;

    address public safe;

    function setUp() public {
        safe = makeAddr("safe");

        mockDepositContract = new MockDepositContract(); 
        contributionVault = new SimpleETHContributionVault(
            safe,
            address(mockDepositContract)
        );
        handler = new SECVHandler(contributionVault);

        targetContract(address(handler));
    }

    function invariant_balanceEqual() public {
        assertEq(
            handler.ETH_SUPPLY(),
            address(handler).balance + contributionVault.userBalances(address(handler))
        );
    }

    function invariant_vaultIsSolvent() public {
        assertEq(
            address(contributionVault).balance,
            handler.ghost_depositSum() - handler.ghost_rageQuitSum()
        );
    }
}
