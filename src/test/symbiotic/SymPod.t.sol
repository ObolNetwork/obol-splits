// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {SymPodFactory} from "src/symbiotic/SymPodFactory.sol";
import {SymPodBeacon} from "src/symbiotic/SymPodBeacon.sol";
import {SymPod, ISymPod} from "src/symbiotic/SymPod.sol";
import {SymPodConfigurator} from "src/symbiotic/SymPodConfigurator.sol";
import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";
import {MockBeaconRootOracle} from "src/test/utils/mocks/MockBeaconRootOracle.sol";
import {MockERC20} from "src/test/utils/mocks/MockERC20.sol";
import {MockETH2Deposit} from "src/test/utils/mocks/MockETH2Deposit.sol";
import {SymPodHarness} from "src/test/harness/SymPodHarness.sol";
import {SymPodProofParser} from "src/test/libraries/SymPodProofParser.sol";
import {BeaconChainProofHarness} from "src/test/harness/BeaconChainProofHarness.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import "forge-std/Test.sol";

contract BaseSymPodTest is Test {
  event CheckpointCreated(uint256 timestamp, bytes32 beaconBlockRoot, uint256 proofsRemaining);

  string podName = "obolTest";
  string podSymbol = "OTK";

  SymPod podImplementation;
  SymPod createdPod;
  SymPodFactory podFactory;
  SymPodBeacon podBeacon;
  SymPodConfigurator podConfigurator;
  MockBeaconRootOracle beaconRootOracle;
  BeaconChainProofHarness beaconChainProofHarness;

  address symPodConfiguratorOwner;
  address podAdmin;
  address withdrawalAddress;
  address recoveryRecipient;
  address slasher;
  SymPodProofParser proofParser;

  uint256 WITHDRAWAL_DELAY_PERIOD = 2 seconds;
  uint256 BALANCE_DELTA_PERCENT = 10_000; // 10%
  address MOCK_ETH2_DEPOSIT_CONTRACT;
  uint256 MAX_ETHER = 1_000_000_000 ether;

  bytes32 blockRoot;

  function setUp() public virtual {
    proofParser = new SymPodProofParser();
    symPodConfiguratorOwner = makeAddr("symPodConfiguratorOwner");
    podAdmin = makeAddr("podAdmin");
    withdrawalAddress = makeAddr("withdrawalAddress");
    recoveryRecipient = makeAddr("recoveryRecipient");
    slasher = makeAddr("slasher");
    MOCK_ETH2_DEPOSIT_CONTRACT = address(new MockETH2Deposit());
    beaconChainProofHarness = new BeaconChainProofHarness();

    podConfigurator = new SymPodConfigurator(symPodConfiguratorOwner);
    beaconRootOracle = new MockBeaconRootOracle();

    podImplementation = new SymPod(
      address(podConfigurator),
      MOCK_ETH2_DEPOSIT_CONTRACT,
      address(beaconRootOracle),
      WITHDRAWAL_DELAY_PERIOD,
      BALANCE_DELTA_PERCENT
    );
    podBeacon = new SymPodBeacon(address(podImplementation), symPodConfiguratorOwner);

    podFactory = new SymPodFactory(address(podBeacon));

    createdPod = SymPod(
      payable(podFactory.createSymPod(podName, podSymbol, slasher, podAdmin, withdrawalAddress, recoveryRecipient))
    );

    // set roots on oracle
    blockRoot = bytes32(uint256(1));
    beaconRootOracle.setBlockRoot(uint64(block.timestamp), blockRoot);
  }

  function roundDown(uint256 x) internal pure returns (uint256 y) {
    y = (x / 1 gwei) * 1 gwei;
  }

  function getTotalValidatorBalances(uint40[] memory validatorIndices, bytes32[] memory balancesRoots)
    internal
    pure
    returns (uint256 totalBalance)
  {
    for (uint256 i = 0; i < validatorIndices.length; i++) {
      totalBalance += BeaconChainProofs.getBalanceAtIndex(balancesRoots[i], validatorIndices[i]);
    }
  }
}

contract BaseSymPodHarnessTest is BaseSymPodTest {
  SymPodHarness podHarnessImplementation;
  SymPodHarness createdHarnessPod;
  SymPodFactory podHarnessFactory;
  SymPodBeacon podHarnessBeacon;

  function setUp() public virtual override {
    super.setUp();

    podHarnessImplementation = new SymPodHarness(
      address(podConfigurator),
      MOCK_ETH2_DEPOSIT_CONTRACT,
      address(beaconRootOracle),
      WITHDRAWAL_DELAY_PERIOD,
      BALANCE_DELTA_PERCENT
    );
    podHarnessBeacon = new SymPodBeacon(address(podHarnessImplementation), symPodConfiguratorOwner);

    podHarnessFactory = new SymPodFactory(address(podHarnessBeacon));

    createdHarnessPod = SymPodHarness(
      payable(
        podHarnessFactory.createSymPod(podName, podSymbol, slasher, podAdmin, withdrawalAddress, recoveryRecipient)
      )
    );
  }
}

contract SymPod__Initialize is BaseSymPodTest {
  event Initialized(address slasher, address admin, address withdrawalAddress, address recoveryRecipient);

  function setUp() public override {
    super.setUp();
  }

  function test_CannotDoublyInitialize() external {
    vm.expectRevert();
    createdPod.initialize("demo", "DMD", slasher, podAdmin, withdrawalAddress, recoveryRecipient);
  }

  function test_CannotUseInvalidSlasher() external {
    vm.expectRevert(ISymPod.SymPod__InvalidAddress.selector);
    podImplementation.initialize("demo", "DMD", address(0), podAdmin, withdrawalAddress, recoveryRecipient);
  }

  function test_CannotUseInvalidAdmin() external {
    vm.expectRevert(ISymPod.SymPod__InvalidAdmin.selector);
    podImplementation.initialize("demo", "DMD", slasher, address(0), withdrawalAddress, recoveryRecipient);
  }

  function test_CannotUseInvalidWithdrawalAddress() external {
    vm.expectRevert(ISymPod.SymPod__InvalidWithdrawalAddress.selector);
    podImplementation.initialize("demo", "DMD", slasher, podAdmin, address(0), recoveryRecipient);
  }

  function test_CannotUseInvalidWithdrawalRecoveryRecipient() external {
    vm.expectRevert(ISymPod.SymPod__InvalidRecoveryAddress.selector);
    podImplementation.initialize("demo", "DMD", slasher, podAdmin, withdrawalAddress, address(0));
  }

  function test_CanInitialize() external {
    vm.expectEmit(true, true, true, true);
    emit Initialized(slasher, podAdmin, withdrawalAddress, recoveryRecipient);

    podImplementation.initialize("demo", "DMD", slasher, podAdmin, withdrawalAddress, recoveryRecipient);

    assertEq(podImplementation.slasher(), slasher, "invalid slasher");

    assertEq(podImplementation.admin(), podAdmin, "invalid slasher");

    assertEq(podImplementation.withdrawalAddress(), withdrawalAddress, "invalid slasher");

    assertEq(podImplementation.recoveryAddress(), recoveryRecipient, "invalid slasher");
  }
}

contract SymPod__Details is BaseSymPodTest {
  function setUp() public override {
    super.setUp();
  }

  function test_Asset() external {
    assertEq(createdPod.asset(), address(0), "invalid asset address");
  }

  function test_Decimals() external {
    assertEq(createdPod.decimals(), 18, "shhould have 18 decimals");
  }

  function test_Name() external {
    assertEq(createdPod.name(), podName, "invalid name");
  }

  function test_Symbol() external {
    assertEq(createdPod.symbol(), podSymbol, "invalid symbol");
  }
}

contract SymPod__RecoverTokens is BaseSymPodHarnessTest {
  MockERC20 airdropToken;
  ERC20[] tokens;
  uint256[] amounts;
  uint256 amountToMint;

  function setUp() public override {
    super.setUp();

    airdropToken = new MockERC20("demo", "demo", 16);
    amountToMint = 1e18;
    airdropToken.mintTo(address(createdPod), type(uint256).max);

    tokens = new ERC20[](1);
    tokens[0] = ERC20(address(airdropToken));

    amounts = new uint256[](1);
    amounts[0] = amountToMint;
  }

  function test_InvalidSize() external {
    vm.expectRevert(ISymPod.SymPod__InvalidTokenAndAmountSize.selector);
    vm.prank(podAdmin);
    createdPod.recoverTokens(tokens, new uint256[](0));
  }

  function test_CannotRecoverTokenIfNotAdmin() external {
    vm.expectRevert(ISymPod.SymPod__Unauthorized.selector);
    createdPod.recoverTokens(tokens, amounts);
  }

  function test_RecoverTokens() external {
    vm.prank(podAdmin);
    createdPod.recoverTokens(tokens, amounts);

    assertEq(airdropToken.balanceOf(createdPod.recoveryAddress()), amountToMint, "invalid amount");
  }

  function testFuzz_RecoverTokens(uint256 amount) external {
    vm.assume(amount > 0);

    uint256[] memory amountToRecover = new uint256[](1);
    amountToRecover[0] = amount;

    vm.prank(podAdmin);
    createdPod.recoverTokens(tokens, amountToRecover);

    assertEq(airdropToken.balanceOf(createdPod.recoveryAddress()), amount, "invalid amount");
  }
}

contract SymPod__Stake is BaseSymPodTest {
  function test_CanStake() public {
    bytes memory pubkey = bytes("setup");
    bytes memory sig = bytes("sig");
    bytes32 depositDataRoot = keccak256(pubkey);

    createdPod.stake{value: 1 ether}(pubkey, sig, depositDataRoot);
  }
}

contract SymPod__StartCheckPoint is BaseSymPodHarnessTest {
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
    assertEq(createdHarnessPod.currentCheckPointTimestamp(), block.timestamp, "invalid current checkpoint timestamp");

    ISymPod.Checkpoint memory currentCheckpoint = createdHarnessPod.getCurrentCheckpoint();

    assertEq(currentCheckpoint.beaconBlockRoot, blockRoot, "invalid block root");

    assertEq(currentCheckpoint.proofsRemaining, numValidators, "invalid number validators");

    assertEq(currentCheckpoint.currentTimestamp, block.timestamp, "invalid timestamp");

    assertEq(currentCheckpoint.balanceDeltasGwei, 0, "invalid delta");
  }

  function test_StartCheckpointWithBalance() external {
    uint256 numValidators = 1;
    uint256 amountOfEther = 10 ether;
    vm.deal(address(createdHarnessPod), amountOfEther);
    // sets the number of validators
    createdHarnessPod.setNumberOfValidators(numValidators);

    vm.expectEmit(true, true, true, true);
    emit CheckpointCreated(block.timestamp, blockRoot, numValidators);

    vm.prank(podAdmin);
    createdHarnessPod.startCheckpoint(true);

    // confirm details here
    assertEq(createdHarnessPod.currentCheckPointTimestamp(), block.timestamp, "invalid current checkpoint timestamp");

    ISymPod.Checkpoint memory currentCheckpoint = createdHarnessPod.getCurrentCheckpoint();

    assertEq(currentCheckpoint.beaconBlockRoot, blockRoot, "invalid block root");

    assertEq(currentCheckpoint.proofsRemaining, numValidators, "invalid number validators");

    assertEq(currentCheckpoint.currentTimestamp, block.timestamp, "invalid timestamp");

    assertEq(currentCheckpoint.podBalanceGwei, amountOfEther / 1 gwei, "invalid pod balance");

    assertEq(currentCheckpoint.balanceDeltasGwei, 0, "invalid pod balance");
  }

  function testFuzz_StartCheckPoint(uint8 numberOfValidators, uint128 amountOfEther) external {
    vm.assume(numberOfValidators > 0);
    vm.assume(amountOfEther > 1 gwei);
    vm.assume((amountOfEther / 1 gwei) < type(uint64).max);

    vm.deal(address(createdHarnessPod), uint256(amountOfEther));
    // sets the number of validators
    createdHarnessPod.setNumberOfValidators(numberOfValidators);

    vm.expectEmit(true, true, true, true);
    emit CheckpointCreated(block.timestamp, blockRoot, numberOfValidators);

    vm.prank(podAdmin);
    createdHarnessPod.startCheckpoint(true);

    // confirm details here
    assertEq(createdHarnessPod.currentCheckPointTimestamp(), block.timestamp, "invalid current checkpoint timestamp");

    ISymPod.Checkpoint memory currentCheckpoint = createdHarnessPod.getCurrentCheckpoint();

    assertEq(currentCheckpoint.podBalanceGwei, amountOfEther / 1 gwei, "invalid pod balance");
  }

  function testFuzz_StartMultipleCheckPoint(uint256 amountOfEther) external {
    vm.assume(amountOfEther > 0);
    amountOfEther = bound(amountOfEther, 2 gwei, 2_000_000_000 ether);

    uint256 amountToDeal = amountOfEther / 2;

    vm.deal(address(createdHarnessPod), amountToDeal);

    // This checkpoint will finalize instantly
    // because its proof remaining will 0
    vm.prank(podAdmin);
    createdHarnessPod.startCheckpoint(true);
    assertEq(createdHarnessPod.withdrawableRestakedPodWei(), roundDown(amountToDeal), "invalid amount");

    // increase block time
    vm.warp(100 seconds);

    beaconRootOracle.setBlockRoot(uint64(block.timestamp), blockRoot);

    // 2nd checkpoint
    vm.deal(address(createdHarnessPod), uint256(amountToDeal * 2));

    vm.prank(podAdmin);
    createdHarnessPod.startCheckpoint(true);
    assertEq(
      createdHarnessPod.withdrawableRestakedPodWei(), roundDown(amountToDeal * 2), "invalid withdrawable balance"
    );
  }
}

contract SymPod__InitWithdraw is BaseSymPodHarnessTest {
  event WithdrawalInitiated(bytes32 withdrawalkey, uint256 amount, uint256 withdrawalTimestamp);

  function test_CannotInitWithdrawIfWithdrawalsPaused() external {
    vm.prank(symPodConfiguratorOwner);
    podConfigurator.pauseWithdrawals();

    vm.expectRevert(ISymPod.SymPod__WithdrawalsPaused.selector);
    vm.prank(podAdmin);
    createdHarnessPod.initWithdraw(1 gwei, 10);
  }

  function test_CannotInitWithdrawIfNoBalance() external {
    vm.expectRevert(ISymPod.SymPod__InsufficientBalance.selector);
    vm.prank(podAdmin);
    createdHarnessPod.initWithdraw(1 gwei, 10);
  }

  function test_CannotInitWithdrawIfNotAdmin() external {
    vm.expectRevert(ISymPod.SymPod__Unauthorized.selector);
    createdHarnessPod.initWithdraw(1 gwei, 10);
  }

  function testFuzz_CanInitWithdraw(uint256 amount, uint256 nonce) external {
    vm.assume(amount > 0);
    vm.assume(nonce > 0);

    amount = bound(amount, 1 gwei, MAX_ETHER);
    amount = roundDown(amount);

    createdHarnessPod.mintSharesPlusAssetsAndRestakedPodWei(amount, podAdmin);

    bytes32 withdrawalKey = createdHarnessPod.getWithdrawalKey(amount, nonce);
    vm.expectEmit(true, true, true, false);
    emit WithdrawalInitiated(withdrawalKey, amount, block.timestamp);
    vm.prank(podAdmin);
    bytes32 key = createdHarnessPod.initWithdraw(amount, 10);

    assertEq(createdHarnessPod.pendingAmountToWithrawWei(), amount, "invalid pending amount");

    // read from withdraw queue
    ISymPod.WithdrawalInfo memory withdrawalInfo = createdHarnessPod.getWithdrawalInfo(key);

    assertEq(withdrawalInfo.owner, podAdmin, "invalid admin");
    assertEq(withdrawalInfo.to, withdrawalAddress, "invalid withdraw");
    assertEq(withdrawalInfo.amountInWei, amount, "invalid amount");
    assertEq(withdrawalInfo.timestamp, block.timestamp + WITHDRAWAL_DELAY_PERIOD, "invalid time");
  }
}

contract SymPod__CompleteWithdraw is BaseSymPodHarnessTest {
  event WithdrawalFinalized(bytes32 withdrawalKey, uint256 actualAmountWithdrawn, uint256 expectedAmountToWithdraw);

  function test_CannotCompleteWithdrawIfWithdrawalsPaused() external {
    vm.prank(symPodConfiguratorOwner);
    podConfigurator.pauseWithdrawals();

    vm.expectRevert(ISymPod.SymPod__WithdrawalsPaused.selector);
    vm.prank(podAdmin);
    createdHarnessPod.completeWithdraw(bytes32(uint256(1)));
  }

  function test_CannotCompleteWithdrawInvalidKey() external {
    vm.expectRevert(ISymPod.SymPod__InvalidWithdrawalKey.selector);
    createdHarnessPod.completeWithdraw(bytes32(uint256(1)));
  }

  function test_CannotCompleteWithdrawInvalidTimestamp() external {
    createdHarnessPod.setWithdrawableRestakedPodWei(1000 gwei);

    vm.prank(podAdmin);
    uint256 amountToWithdraw = 100 gwei;
    bytes32 key = createdHarnessPod.initWithdraw(amountToWithdraw, 100);

    vm.expectRevert(ISymPod.SymPod__WithdrawDelayPeriod.selector);
    createdHarnessPod.completeWithdraw(key);
  }

  function testFuzz_CompleteWithdraw(uint256 amount) external {
    vm.assume(amount > 0);

    uint256 max = 100_000_000 ether;
    amount = bound(amount, 1 gwei, max);
    // round the number down to nearest gwei
    amount = (amount / 1 gwei) * 1 gwei;

    vm.deal(address(createdHarnessPod), amount);

    createdHarnessPod.mintSharesPlusAssetsAndRestakedPodWei(amount, podAdmin);

    vm.prank(podAdmin);
    bytes32 key = createdHarnessPod.initWithdraw(amount, 100);

    vm.warp(1 minutes);
    vm.expectEmit(true, true, true, true);
    emit WithdrawalFinalized(key, amount, amount);

    createdHarnessPod.completeWithdraw(key);

    assertEq(createdHarnessPod.pendingAmountToWithrawWei(), 0, "pending amount to withdraw");

    assertEq(createdHarnessPod.withdrawableRestakedPodWei(), 0, "pending amount to withdraw");

    assertEq(createdHarnessPod.balanceOf(podAdmin), 0, "invalid balance");

    assertEq(address(withdrawalAddress).balance, amount, "invalid balance");

    // ensure withdrawal queue info is deleted
    ISymPod.WithdrawalInfo memory withdrawalInfo = createdHarnessPod.getWithdrawalInfo(key);
    assertEq(withdrawalInfo.owner, address(0), "invalid admin");

    // assert we can't double call completeWithdraw
    vm.expectRevert(ISymPod.SymPod__InvalidWithdrawalKey.selector);
    createdHarnessPod.completeWithdraw(key);
  }

  function testFuzz_CompleteWithdrawHalfBalance(uint256 amount) external {
    vm.assume(amount > 0);

    uint256 max = 100_000_000 ether;
    amount = bound(amount, 1 gwei, max);
    // round the number down to nearest gwei
    amount = (amount / 1 gwei) * 1 gwei;

    vm.deal(address(createdHarnessPod), amount);

    createdHarnessPod.mintSharesPlusAssetsAndRestakedPodWei(amount, podAdmin);

    vm.prank(podAdmin);
    bytes32 key = createdHarnessPod.initWithdraw(amount, 100);

    vm.warp(1 minutes);

    // when the time to complete withdrawal the available to withdraw
    // as reduced by half
    uint256 prevBalance = amount;
    // round down to nearest gwei
    amount = (amount / 2 gwei) * 1 gwei;
    createdHarnessPod.setWithdrawableRestakedPodWei(amount);

    createdHarnessPod.convertToShares(amount);
    createdHarnessPod.completeWithdraw(key);

    // bur
    assertEq(address(withdrawalAddress).balance, amount, "invalid withdrawal balance");

    assertEq(createdHarnessPod.pendingAmountToWithrawWei(), 0, "pending amount to withdraw");

    assertEq(createdHarnessPod.withdrawableRestakedPodWei(), 0, "invalid withdrawable");

    assertEq(createdHarnessPod.balanceOf(podAdmin), prevBalance - amount, "invalid balance");

    // withdrawal key shoud still be deleted
    ISymPod.WithdrawalInfo memory withdrawalInfo = createdHarnessPod.getWithdrawalInfo(key);
    assertEq(withdrawalInfo.owner, address(0), "invalid admin");
  }
}

contract SymPod__onSlash is BaseSymPodHarnessTest {
  uint256 amountToCredit = 1000 gwei;

  function test_CannotSlashIfNotSlasher() external {
    vm.expectRevert(ISymPod.SymPod__NotSlasher.selector);
    createdHarnessPod.onSlash(amountToCredit);
  }

  function test_CannotSlashIfMoreThanBalance() external {
    vm.expectRevert(ISymPod.SymPod__InvalidAmountOfShares.selector);
    vm.prank(slasher);
    createdHarnessPod.onSlash(amountToCredit);
  }

  function test_CannotSlashIfAmountGreaterThanBalance() external {
    createdHarnessPod.mintSharesPlusAssetsAndRestakedPodWei(amountToCredit, slasher);
    createdHarnessPod.setTotalRestakedETH(amountToCredit - 1);
    vm.expectRevert(ISymPod.SymPod__InvalidAmountOfShares.selector);
    vm.prank(slasher);
    createdHarnessPod.onSlash(amountToCredit * 2);
  }

  function testFuzz_onSlash(uint256 amount) external {
    vm.assume(amount > 0);
    amount = roundDown(bound(amount, 1 gwei, MAX_ETHER));

    vm.deal(address(createdHarnessPod), amount);
    createdHarnessPod.mintSharesPlusAssetsAndRestakedPodWei(amount, slasher);

    vm.prank(slasher);
    (bytes32 key) = createdHarnessPod.onSlash(amount);

    assertEq(createdHarnessPod.pendingAmountToWithrawWei(), amount, "invalid amount to credit");

    ISymPod.WithdrawalInfo memory withdrawalInfo = createdHarnessPod.getWithdrawalInfo(key);

    assertEq(withdrawalInfo.owner, slasher, "invalid address");

    assertEq(withdrawalInfo.to, slasher, "invalid slasher address");
    assertEq(withdrawalInfo.amountInWei, amount, "invalid amount to slash");
    assertEq(withdrawalInfo.timestamp, block.timestamp, "invalid timestamp to withdraw");
  }
}

contract SymPod__VerifyWithdrawalCredentials is BaseSymPodHarnessTest {
  string verifyWithdrawalCredentialProofPath =
    "./src/test/test-data/mainnet/VerifyWithdrawalCredential-proof_deneb_mainnet_slot_9575417.json";
  string verifyExitedWithdrawalCredentialProofPath =
    "./src/test/test-data/mainnet/VerifyWithdrawalCredential-exited_proof_deneb_mainnet_slot_9575417.json";

  uint64 timestamp;
  uint256 sizeOfValidators;
  BeaconChainProofs.ValidatorListContainerProof validatorContainerProof;
  BeaconChainProofs.ValidatorsMultiProof validatorProof;

  function setUp() public override {
    super.setUp();

    proofParser.setJSONPath(verifyWithdrawalCredentialProofPath);
    blockRoot = proofParser.getBlockRoot();
    vm.warp(10_000 seconds);

    timestamp = uint64(block.timestamp - 1000);

    validatorContainerProof = BeaconChainProofs.ValidatorListContainerProof({
      validatorListRoot: proofParser.getValidatorListRoot(),
      proof: proofParser.getValidatorListRootProofAgainstBlockRoot()
    });

    uint40[] memory validatorIndices = proofParser.getValidatorIndices();
    sizeOfValidators = validatorIndices.length;
    validatorProof = BeaconChainProofs.ValidatorsMultiProof({
      validatorFields: proofParser.getValidatorFields(validatorIndices.length),
      proof: proofParser.getValidatorFieldsAgainstValidatorListMultiProof(),
      validatorIndices: validatorIndices
    });

    beaconRootOracle.setBlockRoot(timestamp, blockRoot);
  }

  function test_CannotVerifyInvalidTimestamp() external {
    createdHarnessPod.setCurrentCheckpointTimestamp(uint64(block.timestamp + 100));
    vm.expectRevert(ISymPod.SymPod__InvalidTimestamp.selector);
    createdHarnessPod.verifyValidatorWithdrawalCredentials(
      uint64(block.timestamp), validatorContainerProof, validatorProof
    );
  }

  function test_CannotVerifyWithdrawalCredentialsInvalidProof() external {
    validatorProof.proof[0] = bytes32(uint256(1));
    vm.expectRevert(BeaconChainProofs.BeaconChainProofs__InvalidValidatorFieldsMerkleProof.selector);
    createdHarnessPod.verifyValidatorWithdrawalCredentials(timestamp, validatorContainerProof, validatorProof);
  }

  function test_verifyWithdrawalCredentials() external {
    // verify wc
    createdHarnessPod.verifyValidatorWithdrawalCredentials(timestamp, validatorContainerProof, validatorProof);
    // assert the state changes
    uint256 expectedAmount = sizeOfValidators * 32 ether;
    assertEq(createdHarnessPod.totalAssets(), expectedAmount, "invalid total assets");

    assertEq(createdHarnessPod.balanceOf(podAdmin), expectedAmount, "invalid admin balance");

    assertEq(createdHarnessPod.numberOfActiveValidators(), sizeOfValidators, "invalid size of validators");

    // get the validator states

    for (uint256 i = 0; i < validatorProof.validatorFields.length; i++) {
      uint40 validatorIndex = validatorProof.validatorIndices[i];
      bytes32 validatorPubKeyHash = beaconChainProofHarness.getPubkeyHash(validatorProof.validatorFields[i]);

      // fetch validator state
      ISymPod.EthValidator memory validatorInfo = createdHarnessPod.getValidatorInfo(validatorPubKeyHash);

      assertEq(validatorInfo.restakedBalanceGwei, 32 gwei, "invalid balance");

      assertEq(validatorInfo.validatorIndex, validatorIndex, "invalid validator index");

      assertEq(validatorInfo.lastCheckpointedAt, 0, "invalid timestamp");

      assertEq(uint256(validatorInfo.status), uint256(ISymPod.VALIDATOR_STATUS.ACTIVE), "invalid validator state");
    }
  }

  function test_CannotDoublyInitValidatorWCInABlock() external {
    createdHarnessPod.verifyValidatorWithdrawalCredentials(timestamp, validatorContainerProof, validatorProof);

    vm.expectRevert(ISymPod.SymPod__InvalidValidatorState.selector);
    createdHarnessPod.verifyValidatorWithdrawalCredentials(timestamp, validatorContainerProof, validatorProof);
  }

  function test_CannotVerifyInvalidExitEpoch() external {
    proofParser.setJSONPath(verifyExitedWithdrawalCredentialProofPath);
    uint40[] memory validatorIndices = proofParser.getValidatorIndices();
    validatorProof = BeaconChainProofs.ValidatorsMultiProof({
      validatorFields: proofParser.getValidatorFields(validatorIndices.length),
      proof: proofParser.getValidatorFieldsAgainstValidatorListMultiProof(),
      validatorIndices: validatorIndices
    });

    vm.expectRevert(ISymPod.SymPod__InvalidValidatorExitEpoch.selector);
    createdHarnessPod.verifyValidatorWithdrawalCredentials(timestamp, validatorContainerProof, validatorProof);
  }

  function test_CannotVerifyInvalidActivationEpoch() external {
    //     // @TODO get a validator that is about to be activated
    //     validatorProof.validatorFields[0][BeaconChainProofs.VALIDATOR_ACTIVATION_EPOCH_INDEX] = bytes32(uint256(4));
    //     vm.expectRevert(ISymPod.SymPod__InvalidValidatorActivationEpoch.selector);
    //     createdHarnessPod.verifyValidatorWithdrawalCredentials(
    //         timestamp,
    //         validatorContainerProof,
    //         validatorProof
    //     );
  }

  function test_CannotVerifyInvalidWC() external {
    vm.expectRevert(ISymPod.SymPod__InvalidValidatorWithdrawalCredentials.selector);
    createdPod.verifyValidatorWithdrawalCredentials(timestamp, validatorContainerProof, validatorProof);
  }
}

contract SymPod__VerifyBalanceCheckpoints is BaseSymPodHarnessTest {
  event ValidatorBalanceUpdated(
    uint256 currentValidatorIndex,
    uint256 currentTimestamp,
    uint256 oldValidatorBalanceGwei,
    uint256 newValidatorBalanceGwei
  );

  event ValidatorCheckpointUpdate(uint256 checkpointTimestamp, uint256 validatorIndex);

  event CheckpointCompleted(uint256 lastCheckpointTimestamp, int256 totalShareDeltaWei);
  event IncreasedBalance(uint256 totalRestakedEth, uint256 shares);

  string verifyWithdrawalCredentialProofPath =
    "./src/test/test-data/mainnet/VerifyWithdrawalCredential-proof_deneb_mainnet_slot_9575417.json";
  string validatorBalanceProofPath =
    "./src/test/test-data/mainnet/VerifyBalanceCheckpointProof-proof_deneb_mainnet_slot_9575417.json";

  uint64 timestamp;
  uint64 balanceCheckPointTimestamp;
  uint256 sizeOfValidators;

  // all proof use the same validator indices
  BeaconChainProofs.ValidatorListContainerProof validatorContainerProof;
  BeaconChainProofs.ValidatorsMultiProof validatorProof;

  BeaconChainProofs.BalanceContainerProof balanceContainerProof;
  BeaconChainProofs.BalancesMultiProof validatorBalancesProof;

  bytes32 sampleValidatorPubKeyHash;
  uint40 sampleValidatorIndex;

  function setUp() public override {
    super.setUp();

    proofParser.setJSONPath(verifyWithdrawalCredentialProofPath);
    blockRoot = proofParser.getBlockRoot();

    validatorContainerProof = BeaconChainProofs.ValidatorListContainerProof({
      validatorListRoot: proofParser.getValidatorListRoot(),
      proof: proofParser.getValidatorListRootProofAgainstBlockRoot()
    });

    uint40[] memory validatorIndices = proofParser.getValidatorIndices();
    sizeOfValidators = validatorIndices.length;
    validatorProof = BeaconChainProofs.ValidatorsMultiProof({
      validatorFields: proofParser.getValidatorFields(validatorIndices.length),
      proof: proofParser.getValidatorFieldsAgainstValidatorListMultiProof(),
      validatorIndices: validatorIndices
    });

    proofParser.setJSONPath(validatorBalanceProofPath);
    balanceContainerProof = BeaconChainProofs.BalanceContainerProof({
      balanceListRoot: proofParser.getBalanceListRoot(),
      proof: proofParser.getBalanceListRootProofAgainstBlockRoot()
    });

    proofParser.setJSONPath(validatorBalanceProofPath);
    bytes32[] memory validatorPubKeyHashes = proofParser.getValidatorPubKeyHashes();
    validatorBalancesProof = BeaconChainProofs.BalancesMultiProof({
      proof: proofParser.getValidatorBalancesAgainstBalanceRootMultiProof(),
      validatorPubKeyHashes: validatorPubKeyHashes,
      validatorBalanceRoots: proofParser.getValidatorBalancesRoot()
    });

    sampleValidatorPubKeyHash = validatorPubKeyHashes[0];
    sampleValidatorIndex = validatorIndices[0];

    // verify wc
    vm.warp(10_000 seconds);
    timestamp = uint64(block.timestamp - 1000);
    beaconRootOracle.setBlockRoot(timestamp, blockRoot);
    /// verify Withdrawal credentials
    createdHarnessPod.verifyValidatorWithdrawalCredentials(timestamp, validatorContainerProof, validatorProof);
  }

  function test_CannotVerifyForInactiveValidator() external {
    // set a validator status to inactive so it's skipped
    // during verification
    createdHarnessPod.changeValidatorStateToInActive(sampleValidatorPubKeyHash);
    // call start check point
    // move time and set
    vm.warp(200_000 seconds);
    beaconRootOracle.setBlockRoot(uint64(block.timestamp), blockRoot);

    vm.prank(podAdmin);
    createdHarnessPod.startCheckpoint(false);

    // verify balance checkpoint
    createdHarnessPod.verifyBalanceCheckpointProofs({
      balanceContainerProof: balanceContainerProof,
      validatorBalancesProof: validatorBalancesProof
    });
    // uint256 validatorSize = validatorBalancesProof.validatorPubKeyHashes.length;
    // this result checkpoint
    ISymPod.Checkpoint memory currentCheckpoint = createdHarnessPod.getCurrentCheckpoint();

    assertEq(currentCheckpoint.proofsRemaining, 1, "should have one proof remaining to be submitted");
  }

  function test_CannotVerifyForAlreadyCheckpointedValidator() external {
    // set a validator status to inactive so it's skipped
    // during verification
    createdHarnessPod.changeValidatorStateToInActive(sampleValidatorPubKeyHash);
    // call start check point
    // move time and set
    vm.warp(200_000 seconds);

    beaconRootOracle.setBlockRoot(uint64(block.timestamp), blockRoot);

    vm.prank(podAdmin);
    createdHarnessPod.startCheckpoint(false);

    // verify balance checkpoint
    createdHarnessPod.verifyBalanceCheckpointProofs({
      balanceContainerProof: balanceContainerProof,
      validatorBalancesProof: validatorBalancesProof
    });

    // submitted twice
    // assert that ValidatorCheckpointUpdate and ValidatorBalanceUpdated are not emitted
    vm.recordLogs();
    createdHarnessPod.verifyBalanceCheckpointProofs({
      balanceContainerProof: balanceContainerProof,
      validatorBalancesProof: validatorBalancesProof
    });

    Vm.Log[] memory entries = vm.getRecordedLogs();
    assertEq(entries.length, 0, "no event should be emitted");
  }

  function testFuzz_CanVerifyBalanceCheckpoint(uint256 podBalance) external {
    // deal some amount of ether
    podBalance = roundDown(bound(podBalance, 0, MAX_ETHER));
    vm.deal(address(createdHarnessPod), podBalance);
    uint256 podBalanceGwei = podBalance / 1 gwei;
    // disable the calculation for the first validator
    // this will prevent the checkpoint from completing instantly
    // because we are submitting all the validators
    createdHarnessPod.changeValidatorStateToInActive(sampleValidatorPubKeyHash);

    vm.warp(200_000 seconds);
    // balanceCheckPointTimestamp = uint64(block.timestamp - 1_000);
    beaconRootOracle.setBlockRoot(uint64(block.timestamp), blockRoot);

    vm.prank(podAdmin);
    createdHarnessPod.startCheckpoint(false);

    vm.recordLogs();
    createdHarnessPod.verifyBalanceCheckpointProofs({
      balanceContainerProof: balanceContainerProof,
      validatorBalancesProof: validatorBalancesProof
    });

    Vm.Log[] memory emittedEvents = vm.getRecordedLogs();
    // ValidatorBalanceUpdated, ValidatorCheckpointUpdate are emitted
    assertEq(emittedEvents.length, 2 * (sizeOfValidators - 1), "invalid number of events emitted");

    // -1 because we skip first validator
    uint256 currentTotalValidatorBalanceGwei = (32 ether * (sizeOfValidators - 1)) / 1 gwei;
    // fetch the first validator balance gwei
    uint256 firstValidatorBalanceGwei = BeaconChainProofs.getBalanceAtIndex(
      validatorBalancesProof.validatorBalanceRoots[0], validatorProof.validatorIndices[0]
    );

    uint256 newTotalValidatorBalanceMinusFirstValidatorGwei = getTotalValidatorBalances(
      validatorProof.validatorIndices, validatorBalancesProof.validatorBalanceRoots
    ) - firstValidatorBalanceGwei;

    int256 expectedBalanceDeltaGwei =
      int256(newTotalValidatorBalanceMinusFirstValidatorGwei) - int256(currentTotalValidatorBalanceGwei);

    ISymPod.Checkpoint memory currentCheckpoint = createdHarnessPod.getCurrentCheckpoint();

    assertEq(currentCheckpoint.beaconBlockRoot, blockRoot, "invalid block root");
    assertEq(currentCheckpoint.proofsRemaining, 1, "invalid number of proofs remaining");
    assertEq(currentCheckpoint.podBalanceGwei, podBalanceGwei, "invalid pod balance gwei");
    assertEq(expectedBalanceDeltaGwei, currentCheckpoint.balanceDeltasGwei, "invalid balance delta");

    // submit proofs also to complete it
    createdHarnessPod.changeValidatorStateToActive(sampleValidatorPubKeyHash);
    int256 podBalanceWei = int256(podBalanceGwei) * 1 gwei;
    int256 totalValidatorsBalanceWei =
      (int256(newTotalValidatorBalanceMinusFirstValidatorGwei + firstValidatorBalanceGwei) * 1 gwei);
    int256 expectedTotalShareDeltaWei = totalValidatorsBalanceWei - int256((32 ether * sizeOfValidators));
    vm.expectEmit(true, true, true, true);
    emit ValidatorBalanceUpdated(sampleValidatorIndex, block.timestamp, 32 gwei, firstValidatorBalanceGwei);

    vm.expectEmit(true, true, true, true);
    emit ValidatorCheckpointUpdate(block.timestamp, sampleValidatorIndex);

    vm.expectEmit(true, true, true, true);
    emit IncreasedBalance(
      uint256(totalValidatorsBalanceWei + podBalanceWei), uint256(expectedTotalShareDeltaWei + podBalanceWei)
    );

    vm.expectEmit(true, true, true, true);
    emit CheckpointCompleted(block.timestamp, expectedTotalShareDeltaWei + podBalanceWei);

    createdHarnessPod.verifyBalanceCheckpointProofs({
      balanceContainerProof: balanceContainerProof,
      validatorBalancesProof: validatorBalancesProof
    });
    assertEq(
      createdHarnessPod.withdrawableRestakedPodWei(), uint256(podBalanceWei), "invalid withdrawable restaked pod wei"
    );
  }
}

// One more test
contract SymPod__VerifyExpiredBalance is BaseSymPodHarnessTest {
  string expiredBalanceProofFilePath =
    "./src/test/test-data/mainnet/VerifyExpiredBalanceProof-proof_deneb_mainnet_slot_9575417.json";

  uint64 timestamp;
  uint256 sizeOfValidators;
  BeaconChainProofs.ValidatorListContainerProof validatorContainerProof;
  BeaconChainProofs.ValidatorProof validatorFieldsProof;

  bytes32 validatorPubKeyHash;

  function setUp() public override {
    super.setUp();

    proofParser.setJSONPath(expiredBalanceProofFilePath);
    blockRoot = proofParser.getBlockRoot();

    vm.warp(10_000 seconds);

    timestamp = uint64(block.timestamp - 1000);

    validatorContainerProof = BeaconChainProofs.ValidatorListContainerProof({
      validatorListRoot: proofParser.getValidatorListRoot(),
      proof: proofParser.getValidatorListRootProofAgainstBlockRoot()
    });

    uint40 validatorIndex = uint40(proofParser.getValidatorIndex());
    validatorFieldsProof = BeaconChainProofs.ValidatorProof({
      validatorFields: proofParser.getSingleValidatorFields(),
      proof: abi.encodePacked(proofParser.getValidatorFieldsProof()),
      validatorIndex: validatorIndex
    });

    beaconRootOracle.setBlockRoot(timestamp, blockRoot);
    beaconRootOracle.setBlockRoot(uint64(block.timestamp), blockRoot);

    validatorPubKeyHash = validatorFieldsProof.validatorFields[BeaconChainProofs.VALIDATOR_PUBKEY_INDEX];
  }

  function test_CannotVerifyExpiredBalanceIfValidatorNotActive() external {
    vm.expectRevert(ISymPod.SymPod__InvalidValidatorState.selector);
    createdHarnessPod.verifyExpiredBalance({
      beaconTimestamp: timestamp,
      validatorContainerProof: validatorContainerProof,
      validatorProof: validatorFieldsProof
    });
  }

  function test_CannotVerifyIfInvaldBeaconTimestamp() external {
    createdHarnessPod.changeValidatorLastCheckpointedAt(validatorPubKeyHash, timestamp + 10);

    vm.expectRevert(ISymPod.SymPod__InvalidBeaconTimestamp.selector);
    createdHarnessPod.verifyExpiredBalance({
      beaconTimestamp: timestamp,
      validatorContainerProof: validatorContainerProof,
      validatorProof: validatorFieldsProof
    });
  }

  function test_CannotVerifyIfValidatorNotSlashed() external {
    string memory notSlashedExpiredBalanceProofPath =
      "./src/test/test-data/mainnet/VerifyExpiredBalanceProofNotSlashed-proof_deneb_mainnet_slot_9575417.json";
    proofParser.setJSONPath(expiredBalanceProofFilePath);
    uint40 validatorIndex = uint40(proofParser.getValidatorIndex());
    BeaconChainProofs.ValidatorProof memory localValidatorFieldsProof = BeaconChainProofs.ValidatorProof({
      validatorFields: proofParser.getSingleValidatorFields(),
      proof: abi.encodePacked(proofParser.getValidatorFieldsProof()),
      validatorIndex: validatorIndex
    });
    bytes32 currentValidatorPubKeyHash =
      localValidatorFieldsProof.validatorFields[BeaconChainProofs.VALIDATOR_PUBKEY_INDEX];

    createdHarnessPod.changeValidatorStateToActive(currentValidatorPubKeyHash);

    vm.expectRevert(ISymPod.SymPod__ValidatorNotSlashed.selector);
    createdHarnessPod.verifyExpiredBalance({
      beaconTimestamp: timestamp,
      validatorContainerProof: validatorContainerProof,
      validatorProof: localValidatorFieldsProof
    });
  }

  function testFuzz_verifyExpiredBalance(uint256 podBalance) external {
    podBalance = roundDown(bound(podBalance, 0, MAX_ETHER));
    vm.deal(address(createdHarnessPod), podBalance);
    uint256 podBalanceGwei = podBalance / 1 gwei;

    createdHarnessPod.changeValidatorStateToActive(validatorPubKeyHash);
    // to prevent the validators from auto verifying
    uint256 numberOfValidators = 1;
    createdHarnessPod.setNumberOfValidators(numberOfValidators);

    vm.expectEmit(true, true, true, true);
    emit CheckpointCreated(uint64(block.timestamp), blockRoot, numberOfValidators);
    createdHarnessPod.verifyExpiredBalance({
      beaconTimestamp: timestamp,
      validatorContainerProof: validatorContainerProof,
      validatorProof: validatorFieldsProof
    });

    ISymPod.Checkpoint memory currentCheckpoint = createdHarnessPod.getCurrentCheckpoint();
    assertEq(currentCheckpoint.beaconBlockRoot, blockRoot, "invalid block root");
    assertEq(currentCheckpoint.proofsRemaining, numberOfValidators, "invalid number of validators");
    assertEq(currentCheckpoint.podBalanceGwei, podBalanceGwei, "invalid pod balance gwei");

    assertEq(currentCheckpoint.balanceDeltasGwei, 0, "balance delta invalid");
  }
}

contract SymPod__VerifyExceedBalanceDelta is BaseSymPodHarnessTest {
  // we use an exited validator
  string expiredBalanceProofFilePath =
    "./src/test/test-data/mainnet/VerifyExceedBalanceDelta-proof_deneb_mainnet_slot_9575417.json";

  bytes32 validatorPubKeyHash;
  BeaconChainProofs.BalanceContainerProof balanceContainer;
  BeaconChainProofs.BalanceProof balanceProof;

  uint64 timestamp;
  uint40 validatorIndex;

  function setUp() public override {
    super.setUp();

    vm.warp(10_000 seconds);
    timestamp = uint64(block.timestamp - 1000);

    proofParser.setJSONPath(expiredBalanceProofFilePath);
    blockRoot = proofParser.getBlockRoot();
    balanceContainer = BeaconChainProofs.BalanceContainerProof({
      balanceListRoot: proofParser.getBalanceListRoot(),
      proof: proofParser.getBalanceListRootProofAgainstBlockRoot()
    });

    balanceProof = BeaconChainProofs.BalanceProof({
      proof: proofParser.getValidatorBalanceproof(),
      validatorPubKeyHash: proofParser.getValidatorPubKeyHash(),
      validatorBalanceRoot: proofParser.getValidatorBalanceRoot()
    });

    validatorIndex = uint40(proofParser.getValidatorIndex());

    beaconRootOracle.setBlockRoot(timestamp, blockRoot);
    beaconRootOracle.setBlockRoot(uint64(block.timestamp), blockRoot);
  }

  function test_CannotVerifyExceedBalanceIfValidatorNotActive() external {
    vm.expectRevert(ISymPod.SymPod__InvalidValidatorState.selector);
    createdHarnessPod.verifyExceedBalanceDelta({
      beaconTimestamp: timestamp,
      balanceContainer: balanceContainer,
      balanceProof: balanceProof
    });
  }

  function test_CannotVerifyIfInvaldBeaconTimestamp() external {
    createdHarnessPod.changeValidatorLastCheckpointedAt(balanceProof.validatorPubKeyHash, timestamp + 10);

    vm.expectRevert(ISymPod.SymPod__InvalidBeaconTimestamp.selector);
    createdHarnessPod.verifyExceedBalanceDelta({
      beaconTimestamp: timestamp,
      balanceContainer: balanceContainer,
      balanceProof: balanceProof
    });
  }

  function test_CannotVerifyInvalidBalanceDelta() external {
    string memory proofPath =
      "./src/test/test-data/mainnet/VerifyExceedBalanceDeltaNotExited-proof_deneb_mainnet_slot_9575417.json";
    proofParser.setJSONPath(proofPath);

    balanceProof = BeaconChainProofs.BalanceProof({
      proof: proofParser.getValidatorBalanceproof(),
      validatorPubKeyHash: proofParser.getValidatorPubKeyHash(),
      validatorBalanceRoot: proofParser.getValidatorBalanceRoot()
    });
    uint40 currentValidatorIndex = uint40(proofParser.getValidatorIndex());

    createdHarnessPod.changeValidatorStateToActive(balanceProof.validatorPubKeyHash);
    createdHarnessPod.setValidatorIndex(balanceProof.validatorPubKeyHash, currentValidatorIndex);
    createdHarnessPod.setValidatorRestakedGwei(balanceProof.validatorPubKeyHash, 32 gwei);

    vm.expectRevert(ISymPod.SymPod__InvalidBalanceDelta.selector);
    createdHarnessPod.verifyExceedBalanceDelta({
      beaconTimestamp: timestamp,
      balanceContainer: balanceContainer,
      balanceProof: balanceProof
    });
  }

  function testFuzz_verifyExceedBalanceDelta(uint256 podBalance) external {
    podBalance = roundDown(bound(podBalance, 0, MAX_ETHER));
    vm.deal(address(createdHarnessPod), podBalance);
    uint256 podBalanceGwei = podBalance / 1 gwei;

    createdHarnessPod.changeValidatorStateToActive(balanceProof.validatorPubKeyHash);
    createdHarnessPod.setValidatorIndex(balanceProof.validatorPubKeyHash, validatorIndex);
    createdHarnessPod.setValidatorRestakedGwei(balanceProof.validatorPubKeyHash, 32 gwei);

    vm.expectEmit(true, true, true, true);
    emit CheckpointCreated(uint64(block.timestamp), blockRoot, 0);
    createdHarnessPod.verifyExceedBalanceDelta({
      beaconTimestamp: timestamp,
      balanceContainer: balanceContainer,
      balanceProof: balanceProof
    });

    assertEq(createdHarnessPod.withdrawableRestakedPodWei(), podBalanceGwei, "invalid amount to withdraw");
  }
}
