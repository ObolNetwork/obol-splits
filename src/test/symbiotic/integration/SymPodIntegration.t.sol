// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";
import {BaseSymPodHarnessTest, ISymPod} from "../SymPod.t.sol";
import "forge-std/Test.sol";

contract SymPodIntegrationTest is BaseSymPodHarnessTest {
  uint256 MINIMUM_EFFECTIVE_BALANCE = 32 gwei;
  uint256 ONE_SHARE = 1 ether;

  BeaconChainProofs.BalanceRegistryProof balanceRegistryProof;
  BeaconChainProofs.BalancesMultiProof validatorBalancesProof;

  function setUp() public override {
    super.setUp();
  }

  function testFuzz_VerifyWC_StartCP_CompleteCP_Withdraw(
    address user,
    uint256 podBalance
  ) external {
    vm.assume(user != address(0));
    /**
     * The steps are highlighted belwo 
     * 
     * -> Verify withdrawal credentials
     * -> Start Checkpoint
     * -> Complete Checkpoint
     * -> Withdraw
     * -> Verify WC
     * -> Start Checkpoint
     * -> Complete Withdraw
     * 
     */
    // proof is generated using the Obol proof generator repository
    //
    //  The validator indices and slot number used to generate the proof are listed below
    //
    //  https://beaconscan.com/slot/8800000
    //    active   60000 (epoch 320368 )
    //             10000 ( epoch 320368 )
    //    exited   26877 (exit epoch 231119)
    //    slashed  19607 (slot 9249311, epoch 289_040) 
    //             163047 (slot 8831565, epoch 275986)  	
    {
      string memory verifyWithdrawalCredentialProofPath =
      "./src/test/test-data/mainnet/integration/VerifyWithdrawalCredential-proof_deneb_mainnet_slot_8800000.json";
      // Process proofs
      proofParser.setJSONPath(verifyWithdrawalCredentialProofPath);
      blockRoot = proofParser.getBlockRoot();
    }
    (
      BeaconChainProofs.ValidatorRegistryProof memory validatorRegistryProof,
      BeaconChainProofs.ValidatorsMultiProof memory validatorProof,
      uint40[] memory validatorIndices
    ) = _parseWCProof();
    uint256 sizeOfValidators = validatorIndices.length;
    // move time
    advanceEpoch();

    {
      // Verify Withdrawal Credentials
      uint64 timestamp = uint64(block.timestamp - 2);
      // set the block root
      beaconRootOracle.setBlockRoot(timestamp, blockRoot);

      // Verify the Withdrawal Credentials
      createdHarnessPod.verifyValidatorWithdrawalCredentials({
        beaconTimestamp: timestamp,
        validatorRegistryProof: validatorRegistryProof,
        validatorProof: validatorProof
      });
      __assertWithdrawalCredentialChanges(
        validatorProof,
        sizeOfValidators
      );
    }

    advanceEpoch();

    // We bound here with type(uint64).max because 
    // podBalanceGwei is uint64 max in SymPod
    podBalance = bound(podBalance, 0, type(uint64).max);
    // send some ether to the SymPod
    vm.deal(address(createdHarnessPod), podBalance);
    uint256 podBalanceRoundToNearestGweiInWei = roundDown(podBalance);

    // add a block root for the current timestamp
    beaconRootOracle.setBlockRoot(uint64(block.timestamp), blockRoot);
    // Start Checkpoint
    vm.prank(podAdmin);
    createdHarnessPod.startCheckpoint(false);

    __assertStartCheckpointChanges(
      sizeOfValidators,
      blockRoot,
      podBalance
    );

    advanceSlot();

    // Submit Balance Changes
    // This proof still uses the https://beaconscan.com/slot/8800000
    // This works because verifyWC uses effective balance
    {
      {
        string memory verifyBalanceCheckpointProofPath =
        "./src/test/test-data/mainnet/integration/VerifyBalanceCheckpointProof-proof_deneb_mainnet_slot_8800000.json";
        proofParser.setJSONPath(verifyBalanceCheckpointProofPath);
        // the block root is the same it doesnot change
        beaconRootOracle.setBlockRoot(uint64(block.timestamp), blockRoot);
      }

      (
        balanceRegistryProof,
        validatorBalancesProof
      ) = _parseVerifyBCProof();

      // Transfer entire balance from podAdmin to another user
      uint256 currentAdminBalance = createdHarnessPod.balanceOf(podAdmin);
      uint256 prevExchangeRate = createdHarnessPod.convertToAssets(ONE_SHARE);

      vm.prank(podAdmin);
      createdHarnessPod.transfer(user, currentAdminBalance);

      // Verify the first balance checkpoints
      // This would finalize the checkpoint because
      // we are submitting all the necesary proofs
      createdHarnessPod.verifyBalanceCheckpointProofs({
        balanceRegistryProof: balanceRegistryProof,
        validatorBalancesProof: validatorBalancesProof
      });

      assertEq(
        createdHarnessPod.balanceOf(user),
        currentAdminBalance,
        "shares of user should remain the same"
      );

      uint256 totalValidatorBalanceWei = getTotalValidatorBalancesGwei(
        validatorIndices, validatorBalancesProof.validatorBalanceRoots
      ) * 1 gwei;

      // We verify that new shares are minted to the podAdmin
      __assertVerifyBalanceCheckpointChanges(
        podBalanceRoundToNearestGweiInWei,
        validatorIndices,
        validatorBalancesProof
      );

      assertEq(
        createdHarnessPod.balanceOf(podAdmin),
        (totalValidatorBalanceWei + podBalanceRoundToNearestGweiInWei) - currentAdminBalance,
        "new shares should be minted to podAdmin"
      );
      assertEq(
        createdHarnessPod.convertToAssets(ONE_SHARE),
        prevExchangeRate,
        "exchange rate should stay the same"
      );
    }

    advanceEpoch();

    {
      // We start another checkpoint 
      // this time using a different block root where some of the
      // validators have slashed & exited
      // you can know the slashed & exited validators via the table above
      // This means new shares should not be issued
      /*
      * the below proof is generated from this below slot
      * for the indices in the head comment
      * https://beaconscan.com/slot/10254823
      */
      string memory verifyBalanceCheckpointProofPath =
      "./src/test/test-data/mainnet/integration/VerifyBalanceCheckpointProof-proof_deneb_mainnet_slot_10254823.json";
      proofParser.setJSONPath(verifyBalanceCheckpointProofPath);
      // the block root is the same it doesnot change
      blockRoot = proofParser.getBlockRoot();
      beaconRootOracle.setBlockRoot(uint64(block.timestamp), blockRoot);

      uint256 prevTotalRestakedETH = createdHarnessPod.totalAssets();
      uint256 currentAdminBalance = createdHarnessPod.balanceOf(podAdmin);
      uint256 prevExchangeRate = createdHarnessPod.convertToAssets(1 ether);
    
      (
        balanceRegistryProof,
        validatorBalancesProof
      ) = _parseVerifyBCProof();

      uint256 expectedExitedBalanceGwei = calculateExitedValidatorBalances(
        balanceRegistryProof,
        validatorBalancesProof
      );

      vm.prank(podAdmin);
      createdHarnessPod.startCheckpoint(false);
      // Verify Balance Checkpoint
      createdHarnessPod.verifyBalanceCheckpointProofs({
        balanceRegistryProof: balanceRegistryProof,
        validatorBalancesProof: validatorBalancesProof
      });

      __assertValidatorsState(
        balanceRegistryProof,
        validatorBalancesProof
      );
      uint256 totalValidatorBalanceWei = getTotalValidatorBalancesGwei(
        validatorIndices, validatorBalancesProof.validatorBalanceRoots
      ) * 1 gwei;
      uint256 currentExchangeRate = createdHarnessPod.convertToAssets(1 ether);
      // get last checkpoint
      uint256 exitedBalanceGwei = createdHarnessPod.checkpointBalanceExitedGwei(
        createdHarnessPod.lastCheckpointTimestamp()
      );

      assertTrue(exitedBalanceGwei > 0, "some validators have exited balances");
      assertEq(
        exitedBalanceGwei,
        expectedExitedBalanceGwei,
        "exited balance should be eqaul"
      );
      assertEq(
        createdHarnessPod.currentCheckPointTimestamp(),
        0,
        "checkpointed should be finalised"
      );
      assertEq(
        createdHarnessPod.totalAssets(),
        totalValidatorBalanceWei + podBalanceRoundToNearestGweiInWei,
        "incorrect total assets"
      );
      assertEq(
        currentAdminBalance,
        createdHarnessPod.balanceOf(podAdmin),
        "balance of admin should not change"
      );
      assertTrue(prevTotalRestakedETH > createdHarnessPod.totalAssets(), "total restaked eth should reduce");
      assertTrue(prevExchangeRate > currentExchangeRate, "exchange rate for 1 share should reduce");
    }

    advanceSlot();

    // Slash
    {
      // transfer funds to be slashed to slasher
      // Given that the 
      uint256 balance = createdHarnessPod.balanceOf(user);

      vm.prank(user);
      createdHarnessPod.transfer(address(slasher), balance);

      uint256 amountInWei = createdHarnessPod.convertToAssets(createdHarnessPod.balanceOf(slasher));

      assertTrue(
        amountInWei > createdHarnessPod.withdrawableRestakedPodWei(),
        "amount to withdraw should be greater than it"
      );

      vm.prank(address(slasher));
      bytes32 withdrawalKey = createdHarnessPod.onSlash(
        amountInWei
      );

      assertEq(
        createdHarnessPod.pendingAmountToWithdrawWei(),
        amountInWei,
        "invalid  pending amount set"
      );

      uint256 amountReceived = createdHarnessPod.completeWithdraw(withdrawalKey);
      if (podBalanceRoundToNearestGweiInWei > 0) {
        assertTrue(
          amountReceived > 0,
          "incorrect amount received"
        );
        assertEq(
          createdHarnessPod.pendingAmountToWithdrawWei(),
          0,
          "incorrect pending amount to withdraw"
        );
      } else {
        assertTrue(
          amountReceived == 0,
          "incorrect amount received"
        );
      }
      // The slasher should have shares left
      // because there isn't enough wei to service the
      // withdrawal
      assertTrue(
        createdHarnessPod.balanceOf(slasher) > 0,
        "there should not be enough wei"
      );

    }

    advanceEpoch();

    // Checkpoint Again
    // To add withdrawable Wei
    {
      
      beaconRootOracle.setBlockRoot(uint64(block.timestamp), blockRoot);

      uint256 balance = createdHarnessPod.balanceOf(podAdmin);
      uint256 assets = createdHarnessPod.convertToAssets(balance);
      // uint256 assetsToNearestGwei = roundDown(assets);
      uint256 amountToDeposit = roundDown(createdHarnessPod.pendingAmountToWithdrawWei() + assets);
      // send the eth to 
      vm.deal(address(createdHarnessPod), createdHarnessPod.pendingAmountToWithdrawWei() + assets);

      // Use checkpoint to track the new deposit ETH
      vm.prank(podAdmin);
      createdHarnessPod.startCheckpoint(false);
      // Verify Balance Checkpoint
      createdHarnessPod.verifyBalanceCheckpointProofs({
        balanceRegistryProof: balanceRegistryProof,
        validatorBalancesProof: validatorBalancesProof
      });

      assertEq(
        amountToDeposit,
        createdHarnessPod.withdrawableRestakedPodWei(),
        "withdrawable is not properly tracked"
      );
      assertEq(
        createdHarnessPod.currentCheckPointTimestamp(),
        0,
        "checkpoint should be finalised"
      );
    }

    // Withdraw
    {
      uint256 balance = createdHarnessPod.balanceOf(podAdmin);
      uint256 availableAmountWei = createdHarnessPod.convertToAssets(balance);
      uint256 amountWei = createdHarnessPod.withdrawableRestakedPodWei() - createdHarnessPod.pendingAmountToWithdrawWei();

      assertTrue(
        availableAmountWei > amountWei,
        "admin available to  withdraw should be greater than"
      );

      vm.prank(podAdmin);
      bytes32 withdrawalKey = createdHarnessPod.initWithdraw(
        amountWei,
        1
      );

      // move past withdrawal delay period
      advanceEpoch();

      uint256 amountReceived = createdHarnessPod.completeWithdraw(withdrawalKey);
      assertTrue(
        amountReceived > 0,
        "invalid amount received in withdraw"
      );
    }
  }

  function _parseWCProof() internal returns (
    BeaconChainProofs.ValidatorRegistryProof memory validatorRegistryProof,
    BeaconChainProofs.ValidatorsMultiProof memory validatorProof,
    uint40[] memory validatorIndices
  ) {
    validatorRegistryProof = BeaconChainProofs.ValidatorRegistryProof({
      validatorListRoot: proofParser.getValidatorListRoot(),
      proof: proofParser.getValidatorListRootProofAgainstBlockRoot()
    });
    validatorIndices = proofParser.getValidatorIndices();
    validatorProof = BeaconChainProofs.ValidatorsMultiProof({
      validatorFields: proofParser.getValidatorFields(validatorIndices.length),
      proof: proofParser.getValidatorFieldsAgainstValidatorListMultiProof(),
      validatorIndices: validatorIndices
    });
  }

  function _parseVerifyBCProof() internal returns (
    BeaconChainProofs.BalanceRegistryProof memory currentBalanceContainerProof,
    BeaconChainProofs.BalancesMultiProof memory currentValidatorBalancesProof
  ) {

    currentBalanceContainerProof = BeaconChainProofs.BalanceRegistryProof({
      balanceListRoot: proofParser.getBalanceListRoot(),
      proof: proofParser.getBalanceListRootProofAgainstBlockRoot()
    });

    bytes32[] memory validatorPubKeyHashes = proofParser.getValidatorPubKeyHashes();
    currentValidatorBalancesProof = BeaconChainProofs.BalancesMultiProof({
      proof: proofParser.getValidatorBalancesAgainstBalanceRootMultiProof(),
      validatorPubKeyHashes: validatorPubKeyHashes,
      validatorBalanceRoots: proofParser.getValidatorBalancesRoot()
    });
  }

  function __assertWithdrawalCredentialChanges(
    BeaconChainProofs.ValidatorsMultiProof memory validatorProof,
    uint256 sizeOfValidators
  ) internal {
    uint256 expectedAmount = sizeOfValidators * MINIMUM_EFFECTIVE_BALANCE;

    assertEq(createdHarnessPod.totalAssets(), expectedAmount * 1 gwei, "invalid total assets in wei");
    assertEq(createdHarnessPod.balanceOf(podAdmin), expectedAmount * 1 gwei, "invalid admin balance in wei");
    assertEq(createdHarnessPod.numberOfActiveValidators(), sizeOfValidators, "invalid size of validators");

    for (uint256 i = 0; i < validatorProof.validatorFields.length; i++) {
      uint40 validatorIndex = validatorProof.validatorIndices[i];
      bytes32 validatorPubKeyHash = beaconChainProofHarness.getPubkeyHash(validatorProof.validatorFields[i]);

      // fetch validator state
      ISymPod.EthValidator memory validatorInfo = createdHarnessPod.getValidatorInfo(validatorPubKeyHash);

      assertEq(validatorInfo.restakedBalanceGwei, MINIMUM_EFFECTIVE_BALANCE, "invalid balance");
      assertEq(validatorInfo.validatorIndex, validatorIndex, "invalid validator index");
      assertEq(validatorInfo.lastCheckpointedAt, 0, "invalid timestamp");
      assertEq(uint256(validatorInfo.status), uint256(ISymPod.VALIDATOR_STATE.ACTIVE), "invalid validator state");
    }
  }

  function __assertStartCheckpointChanges(
    uint256 numValidators,
    bytes32 expectedBlockRoot,
    uint256 amountOfEther
  ) internal {
    // confirm details here
    assertEq(createdHarnessPod.currentCheckPointTimestamp(), block.timestamp, "invalid current checkpoint timestamp");
    ISymPod.Checkpoint memory currentCheckpoint = createdHarnessPod.getCurrentCheckpoint();

    assertEq(currentCheckpoint.beaconBlockRoot, expectedBlockRoot, "invalid block root");
    assertEq(currentCheckpoint.pendingProofs, numValidators, "invalid number validators");
    assertEq(currentCheckpoint.currentTimestamp, block.timestamp, "invalid timestamp");
    assertEq(currentCheckpoint.podBalanceGwei, amountOfEther / 1 gwei, "invalid pod balance");
    assertEq(currentCheckpoint.balanceDeltasGwei, 0, "invalid pod balance");
  }

  function __assertInitWithdrawChanges(

  ) internal {

  }

  function __assertVerifyBalanceCheckpointChanges(
    uint256 podBalanceWei,
    uint40[] memory validatorIndices,
    BeaconChainProofs.BalancesMultiProof memory currentValidatorBalancesProof
  ) internal {
    assertEq(
      createdHarnessPod.withdrawableRestakedPodWei(), uint256(podBalanceWei), "invalid withdrawable restaked pod wei"
    );
    uint256 totalValidatorBalanceGwei = getTotalValidatorBalancesGwei(
      validatorIndices, currentValidatorBalancesProof.validatorBalanceRoots
    );

    assertEq(
      createdHarnessPod.totalSupply(),
      podBalanceWei + (totalValidatorBalanceGwei * 1 gwei),
      "__assertVerifyBalanceCheckpointChanges -> invalid total suppply"
    );
  }

  function calculateExitedValidatorBalances(
    BeaconChainProofs.BalanceRegistryProof memory currentBalanceRegistryProof,
    BeaconChainProofs.BalancesMultiProof memory currentValidatorBalancesProof
  ) internal view returns (uint256 exitedBalances) {
    uint40[] memory validatorIndices = createdHarnessPod.getValidatorIndices(currentValidatorBalancesProof.validatorPubKeyHashes);
    uint256[] memory validatorBalances = beaconChainProofHarness.verifyMultiValidatorBalancesProof({
      balanceListRoot: currentBalanceRegistryProof.balanceListRoot,
      proof: currentValidatorBalancesProof.proof,
      validatorIndices: validatorIndices,
      validatorBalances: currentValidatorBalancesProof.validatorBalanceRoots
    });

    return createdHarnessPod.calculateExitedValidatorBalance(
      validatorBalancesProof.validatorPubKeyHashes,
      validatorBalances
    );
  }

  function __assertValidatorsState(
    BeaconChainProofs.BalanceRegistryProof memory currentBalanceRegistryProof,
    BeaconChainProofs.BalancesMultiProof memory currentValidatorBalancesProof
  ) internal {
    uint40[] memory validatorIndices = createdHarnessPod.getValidatorIndices(currentValidatorBalancesProof.validatorPubKeyHashes);
    uint256[] memory validatorBalances = beaconChainProofHarness.verifyMultiValidatorBalancesProof({
      balanceListRoot: currentBalanceRegistryProof.balanceListRoot,
      proof: currentValidatorBalancesProof.proof,
      validatorIndices: validatorIndices,
      validatorBalances: currentValidatorBalancesProof.validatorBalanceRoots
    });

    for(uint256 i = 0; i < currentValidatorBalancesProof.validatorPubKeyHashes.length; i++) {
      bytes32 validatorPubKeyHash = currentValidatorBalancesProof.validatorPubKeyHashes[i];
      ISymPod.EthValidator memory currentValidatorInfo = createdHarnessPod.getValidatorInfo(validatorPubKeyHash);

      if (validatorBalances[i] == 0) {
        // then validator state should be withdrawn
        assertEq(
          uint256(currentValidatorInfo.status),
          uint256(ISymPod.VALIDATOR_STATE.WITHDRAWN),
          "incorrect validator state"
        );
      }

    }
  }
  

}