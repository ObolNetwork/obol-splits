// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {MockERC20} from "src/test/utils/mocks/MockERC20.sol";
import {SimpleETHContributionVault} from "src/safe-modules/SimpleETHContributionVault.sol";


contract SimpleETHContributionVaultTest is Test {

  error CannotRageQuit();
  error Unauthorized(address user);

  event Deposit(address to, uint256 amount);
  event DepositValidator(
    bytes[] pubkeys, bytes[] withdrawal_credentials, bytes[] signatures, bytes32[] deposit_data_roots
  );
  event RageQuit(address to, uint256 amount);
  event RescueFunds(uint256 amount);

  address constant ETH_DEPOSIT_CONTRACT = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
  uint256 internal constant ETH_STAKE = 32 ether;

  SimpleETHContributionVault contributionVault;

  address safe;
  address user1;
  address user2;
  address user3;
  MockERC20 mERC20;

  function setUp() public {
    uint256 mainnetBlock = 17_421_005;
    vm.createSelectFork(getChain("mainnet").rpcUrl, mainnetBlock);

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
    (bool _success,) = payable(contributionVault).call{value: ETH_STAKE}("");
    assertTrue(_success, "call failed");

    assertEq(contributionVault.userBalances(user1), ETH_STAKE, "failed to credit user balance");
  }

  function testFuzz_deposit(address user, uint256 amount) external {
    vm.assume(amount > 0);
    vm.assume(user != address(0));

    vm.deal(user, amount);

    vm.expectEmit(false, false, false, true);
    emit Deposit(user, amount);

    vm.prank(user);
    (bool _success,) = payable(contributionVault).call{value: amount}("");
    assertTrue(_success, "call failed");

    assertEq(contributionVault.userBalances(user), amount);
  }

  function test_rageQuit() external {
    vm.deal(user1, ETH_STAKE);
    
    vm.prank(user1);
    (bool _success,) = payable(contributionVault).call{value: ETH_STAKE}("");
    assertTrue(_success, "call failed");


    vm.expectEmit(false, false, false, true);
    emit RageQuit(user1, ETH_STAKE);

    vm.prank(user1);
    contributionVault.rageQuit(user1, ETH_STAKE);
  }

  function testFuzz_rageQuit(address user, uint256 amount) external {
    vm.assume(amount > 0);
    vm.assume(user != address(0));

    vm.deal(user, amount);

    vm.prank(user);
    (bool _success,) = payable(contributionVault).call{value: amount}("");
    assertTrue(_success, "call failed");

    vm.expectEmit(false, false, false, true);
    emit RageQuit(user, amount);

    vm.prank(user);
    contributionVault.rageQuit(user, amount);
  }

  function test_cannotRageQuitAfterDeposit() external {
    vm.deal(user1, ETH_STAKE);

    vm.prank(user1);
    (bool _success,) = payable(contributionVault).call{value: ETH_STAKE}("");
    assertTrue(_success, "call failed");

    (
      bytes[] memory pubkeys,
      bytes[] memory withdrawal_credentials,
      bytes[] memory signatures,
      bytes32[] memory deposit_data_roots
    ) = getETHValidatorData();

    vm.prank(safe);
    contributionVault.depositValidator(pubkeys, withdrawal_credentials, signatures, deposit_data_roots);

    vm.expectRevert(CannotRageQuit.selector);

    vm.prank(user1);
    contributionVault.rageQuit(user1, ETH_STAKE);
  }

  function test_depositValidator() external {
    vm.deal(user1, ETH_STAKE);

    vm.prank(user1);
    (bool _success,) = payable(contributionVault).call{value: ETH_STAKE}("");
    assertTrue(_success, "call failed");

    (
      bytes[] memory pubkeys,
      bytes[] memory withdrawal_credentials,
      bytes[] memory signatures,
      bytes32[] memory deposit_data_roots
    ) = getETHValidatorData();

    vm.prank(safe);
    contributionVault.depositValidator(pubkeys, withdrawal_credentials, signatures, deposit_data_roots);
  }

  function test_OnlySafeDepositValidator() external {
    (
      bytes[] memory pubkeys,
      bytes[] memory withdrawal_credentials,
      bytes[] memory signatures,
      bytes32[] memory deposit_data_roots
    ) = getETHValidatorData();

    vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, address(this)));
    contributionVault.depositValidator(pubkeys, withdrawal_credentials, signatures, deposit_data_roots);
  }

  function test_rescueFunds() external {
    uint256 amount = 1 ether;
    mERC20.transfer(address(contributionVault), amount);

    vm.expectEmit(false, false, false, true);
    emit RescueFunds(amount);

    contributionVault.rescueFunds(address(mERC20), amount);
  }

  function testFuzz_rescueFundETH(uint256 amount) external {
    vm.assume(amount > 0);

    mERC20.transfer(address(contributionVault), amount);
    vm.expectEmit(false, false, false, true);
    emit RescueFunds(amount);

    contributionVault.rescueFunds(address(mERC20), amount);
  }
}

function getETHValidatorData()
  pure
  returns (
    bytes[] memory pubkeys,
    bytes[] memory withdrawal_credentials,
    bytes[] memory signatures,
    bytes32[] memory deposit_data_roots
  )
{
  pubkeys = new bytes[](1);
  pubkeys[0] =
    bytes(abi.encodePacked(hex"83fa9495bb0944a74fc6a66e699039b66134b22a52a710f8d0f7cde318a2db3da40081a5867667389d206e21b5e37e52"));

  withdrawal_credentials = new bytes[](1);
  withdrawal_credentials[0] = bytes(abi.encodePacked(hex"010000000000000000000000e839a3e9efb32c6a56ab7128e51056585275506c"));

  signatures = new bytes[](1);
  signatures[0] = bytes(
    abi.encodePacked(hex"95f00435e80e59a8fed41581e2050a3fe56272d6be845686ef014a57909c6621d7847fa550b77cb8e541b955f3c2ea031983d9e4336f215e75c8ba75d94e05f1e23460de6611a980ef629d3e32ca09cffaf2a63372496079b1ee22310d336ded")
  );

  deposit_data_roots = new bytes32[](1);
  deposit_data_roots[0] = bytes32(0x2d33b096d02f7a53dbbdaf840755dfc6b9269be39cff6b0d2701d15b4c1b639c);
}
