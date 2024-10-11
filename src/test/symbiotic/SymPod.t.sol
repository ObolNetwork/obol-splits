// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import {SymPodFactory} from "src/symbiotic/SymPodFactory.sol";
import {SymPodBeacon} from "src/symbiotic/SymPodBeacon.sol";
import {SymPod, ISymPod} from "src/symbiotic/SymPod.sol";
import {SymPodConfigurator} from "src/symbiotic/SymPodConfigurator.sol";
import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";
import {MockBeaconRootOracle} from "src/test/utils/mocks/MockBeaconRootOracle.sol";
import {MockETH2Deposit} from "src/test/utils/mocks/MockETH2Deposit.sol";
import {SymPodHarness} from "src/test/harness/SymPodHarness.sol";
import {SymPodProofParser} from "src/test/libraries/SymPodProofParser.sol";
import {BeaconChainProofHarness} from "src/test/harness/BeaconChainProofHarness.sol";
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
    BeaconChainProofHarness beaconChainProofHarness;

    address symPodConfiguratorOwner;
    address podAdmin;
    address withdrawalAddress;
    address recoveryRecipient;
    address slasher;
    SymPodProofParser proofParser;

    uint256 WITHDRAWAL_DELAY_PERIOD = 2 seconds;
    uint256 BALANCE_DELTA_PERCENT = 1_000; // 10%
    address MOCK_ETH2_DEPOSIT_CONTRACT;

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
        podBeacon = new SymPodBeacon(
            address(podImplementation),
            symPodConfiguratorOwner
        );

        podFactory = new SymPodFactory(address(podBeacon));

        createdPod = SymPod(payable(podFactory.createSymPod(
            podName,
            podSymbol,
            slasher,
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

    function setUp() public virtual override {
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
            slasher,
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

        ISymPod.Checkpoint memory currentCheckpoint = createdHarnessPod.getCurrentCheckpoint();

        assertEq(
            currentCheckpoint.beaconBlockRoot,
            blockRoot,
            "invalid block root"
        );

        assertEq(
            currentCheckpoint.proofsRemaining,
            numValidators,
            "invalid number validators"
        );

        assertEq(
            currentCheckpoint.currentTimestamp,
            block.timestamp,
            "invalid timestamp"
        );

        assertEq(
            currentCheckpoint.balanceDeltasGwei,
            0,
            "invalid delta"
        );
    }
}


contract SymPod__InitWithdraw is BaseSymPodHarnessTest {

    event WithdrawalInitiated(
        bytes32 withdrawalkey,
        uint256 amount,
        uint256 withdrawalTimestamp
    );

    function test_CannotInitWithdrawIfWithdrawalsPaused() external {
        vm.prank(symPodConfiguratorOwner);
        podConfigurator.pauseWithdrawals();

        vm.expectRevert(ISymPod.SymPod__WithdrawalsPaused.selector);
        vm.prank(podAdmin);
        createdHarnessPod.initWithdraw(
            1 gwei,
            10
        );
    }

    function test_CannotInitWithdrawIfNoBalance() external {
        vm.expectRevert(ISymPod.SymPod__InsufficientBalance.selector);
        vm.prank(podAdmin);
        createdHarnessPod.initWithdraw(
            1 gwei,
            10
        );
    }

    function test_CannotInitWithdrawIfNotAdmin() external {
        vm.expectRevert(ISymPod.SymPod__Unauthorized.selector);
        createdHarnessPod.initWithdraw(
            1 gwei,
            10
        );
    }

    function test_CanInitWithdraw() external {
        createdHarnessPod.setWithdrawableExecutionLayerGwei(100);

        uint256 amountToWithdraw = 10 gwei;

        // vm.expectEmit(true, true, true, true);
        // emit WithdrawalInitiated(
        //     podAdmin,
        //     withdrawalAddress,
        //     amountToWithdraw,
        //     block.timestamp
        // );
        vm.prank(podAdmin);
        bytes32 key = createdHarnessPod.initWithdraw(
            amountToWithdraw,
            10
        );
        
        assertEq(
            createdHarnessPod.pendingAmountToWithrawWei(),
            amountToWithdraw,
            "invalid pending amount"
        );

        // read from withdraw queue
        ISymPod.WithdrawalInfo memory withdrawalInfo = createdHarnessPod.getWithdrawalInfo(key);

        assertEq(withdrawalInfo.owner, podAdmin, "invalid admin");
        assertEq(withdrawalInfo.to, withdrawalAddress, "invalid withdraw");
        assertEq(withdrawalInfo.amountInWei, amountToWithdraw, "invalid amount");
        assertEq(withdrawalInfo.timestamp, block.timestamp + WITHDRAWAL_DELAY_PERIOD, "invalid time");
    }
}

contract SymPod__CompleteWithdraw is BaseSymPodHarnessTest {

    event WithdrawalFinalized(
        bytes32 withdrawalKey,
        uint256 actualAmountWithdrawn,
        uint256 expectedAmountToWithdraw
    );

    function test_CannotCompleteWithdrawIfWithdrawalsPaused() external {
        vm.prank(symPodConfiguratorOwner);
        podConfigurator.pauseWithdrawals();

        vm.expectRevert(ISymPod.SymPod__WithdrawalsPaused.selector);
        vm.prank(podAdmin);
        createdHarnessPod.completeWithdraw(
            bytes32(uint256(1))
        );
    }

    function test_CannotCompleteWithdrawInvalidKey() external {
        vm.expectRevert(ISymPod.SymPod__InvalidWithdrawalKey.selector);
        createdHarnessPod.completeWithdraw(
            bytes32(uint256(1))
        );
    }

    function test_CannotCompleteWithdrawInvalidTimestamp() external {
        createdHarnessPod.setWithdrawableExecutionLayerGwei(1000 gwei);

        vm.prank(podAdmin);
        uint256 amountToWithdraw = 100 gwei;
        bytes32 key = createdHarnessPod.initWithdraw(
            amountToWithdraw,
            100
        );

        vm.expectRevert(ISymPod.SymPod__WithdrawDelayPeriod.selector);
        createdHarnessPod.completeWithdraw(
            key
        );
    }

    // function test_CannotCompleteWithdrawIfOngoingCheckpoint() external {
    //     createdHarnessPod.setNumberOfValidators(1);
    //     createdHarnessPod.startCheckpoint(false);

    //     vm.expectRevert(ISymPod.SymPod__WithdrawalsPaused.selector);
    //     vm.prank(podAdmin);
    //     createdHarnessPod.completeWithdraw(
    //         bytes32(uint256(1)),
    //         false
    //     );
    // }

    function test_completeWithdraw() external {
        vm.deal(address(createdHarnessPod), 1000 ether);
        uint256 amountToCredit = 1000 gwei;
        createdHarnessPod.mintSharesPlusAssetsAndExecutionLayerGwei(amountToCredit, podAdmin);

        uint256 amountToWithdraw = 100 gwei;
        vm.prank(podAdmin);
        bytes32 key = createdHarnessPod.initWithdraw(
            amountToWithdraw,
            100
        );

        vm.warp(1 minutes);
        vm.expectEmit(true, true, true, true);
        emit WithdrawalFinalized(
            key,
            amountToWithdraw,
            amountToWithdraw
        );
        uint256 amountReceived = createdHarnessPod.completeWithdraw(
            key
        );

        assertEq(
            createdHarnessPod.pendingAmountToWithrawWei(),
            0,
            "pending amount to withdraw"
        );

        assertEq(
            createdHarnessPod.withdrawableRestakedExecutionLayerGwei(),
            amountToCredit - (amountToWithdraw / 1 gwei),
            "pending amount to withdraw"
        );

        assertEq(
            createdHarnessPod.balanceOf(podAdmin),
            amountToCredit - amountToWithdraw,
            "invalid balance"
        );
    }
}

contract SymPod__onSlash is BaseSymPodHarnessTest {
     uint256 amountToCredit = 1000 gwei; 
    function test_CannotSlashIfNotSlasher() external {
        vm.expectRevert(ISymPod.SymPod__NotSlasher.selector);
        createdHarnessPod.onSlash(
            amountToCredit,
            100
        );
    }

    function test_CannotSlashIfMoreThanBalance() external {
        vm.expectRevert(ISymPod.SymPod__InvalidAmountOfShares.selector);
        vm.prank(slasher);
        createdHarnessPod.onSlash(
            amountToCredit,
            100
        );
    }

    // function test_CannotSlashIfAmountGreaterThanBalance() external {
    //     createdHarnessPod.mintSharesPlusAssetsAndExecutionLayerGwei(amountToCredit, slasher);
    //     createdHarnessPod.setTotalRestakedETH(amountToCredit - 1);
    //     vm.expectRevert(ISymPod.SymPod__AmountTooLarge.selector);
    //     vm.prank(slasher);
    //     createdHarnessPod.onSlash(
    //         amountToCredit,
    //         100
    //     );
    // }

    function test_onSlash() external {
        vm.deal(address(createdHarnessPod), 1000 ether);
        createdHarnessPod.mintSharesPlusAssetsAndExecutionLayerGwei(amountToCredit, slasher);

        vm.prank(slasher);
        (bytes32 key, uint256 amount) = createdHarnessPod.onSlash(
            amountToCredit,
            100
        );

        assertEq(
            createdHarnessPod.pendingAmountToWithrawWei(),
            amountToCredit,
            "invalid amount to credit"
        );

        ISymPod.WithdrawalInfo memory withdrawalInfo = createdHarnessPod.getWithdrawalInfo(key);

        assertEq(
            withdrawalInfo.owner,
            slasher,
            "invalid address"
        );

        assertEq(
            withdrawalInfo.to,
            slasher,
            "invalid slasher address"
        );
        assertEq(
            withdrawalInfo.amountInWei,
            amountToCredit,
            "invalid amount to slash"
        );
        assertEq(
            withdrawalInfo.timestamp,
            block.timestamp,
            "invalid timestamp to withdraw"
        );
    }
}

contract SymPod__VerifyWithdrawalCredentials is BaseSymPodHarnessTest {

    uint64 timestamp;
    uint256 sizeOfValidators;
    BeaconChainProofs.ValidatorListContainerProof validatorContainerProof;
    BeaconChainProofs.ValidatorsMultiProof validatorProof;

    function setUp() override public {
        
        super.setUp();
        string memory validatorFieldsProofFilePath = "./src/test/test-data/ValidatorFields-proof.json";
        string memory validatorListRootProofFilePath = "./src/test/test-data/ValidatorListRootProof-proof.json";

        proofParser.setJSONPath(validatorListRootProofFilePath);
        blockRoot = proofParser.getBlockRoot();
        vm.warp(10000 seconds);

        timestamp = uint64(block.timestamp - 1_000);

        validatorContainerProof = BeaconChainProofs.ValidatorListContainerProof({
            validatorListRoot: proofParser.getValidatorListRoot(),
            proof: proofParser.getValidatorListRootProofAgainstBlockRoot()
        });

        proofParser.setJSONPath(validatorFieldsProofFilePath);
        uint40[] memory validatorIndices = proofParser.getValidatorIndices();
        sizeOfValidators = validatorIndices.length;
        validatorProof = BeaconChainProofs.ValidatorsMultiProof({
            validatorFields: proofParser.getValidatorFields(validatorIndices.length),
            proof: proofParser.getValidatorFieldsProof(),
            validatorIndices: validatorIndices
        });

        beaconRootOracle.setBlockRoot(timestamp, blockRoot);
    }

    function test_CannotVerifyWithdrawalCredentialsInvalidProof() external {
        validatorProof.proof[0] = bytes32(uint256(1));
        vm.expectRevert(
            BeaconChainProofs.BeaconChainProofs__InvalidValidatorFieldsMerkleProof.selector
        );
        createdHarnessPod.verifyValidatorWithdrawalCredentials(
            timestamp,
            validatorContainerProof,
            validatorProof
        );
    }

    function test_verifyWithdrawalCredentials() external {
        // verify wc
        createdHarnessPod.verifyValidatorWithdrawalCredentials(
            timestamp,
            validatorContainerProof,
            validatorProof
        );
        // assert the state changes
        uint256 expectedAmount = sizeOfValidators * 32 ether;
        assertEq(
            createdHarnessPod.totalAssets(),
            expectedAmount,
            "invalid total assets"
        );

        assertEq(
            createdHarnessPod.balanceOf(podAdmin),
            expectedAmount,
            "invalid admin balance"
        );

        assertEq(
            createdHarnessPod.numberOfActiveValidators(),
            sizeOfValidators,
            "invalid size of validators"
        );

        // get the validator states

        for (uint i = 0; i < validatorProof.validatorFields.length; i++) {
            uint40 validatorIndex = validatorProof.validatorIndices[i];
            bytes32 validatorPubKeyHash = beaconChainProofHarness.getPubkeyHash(validatorProof.validatorFields[i]);

            // fetch validator state
            ISymPod.EthValidator memory validatorInfo = createdHarnessPod.getValidatorInfo(validatorPubKeyHash);

            assertEq(
                validatorInfo.restakedBalanceGwei,
                32 gwei,
                "invalid balance"
            );

            assertEq(
                validatorInfo.validatorIndex,
                validatorIndex,
                "invalid validator index"
            );

            assertEq(
                validatorInfo.lastCheckpointedAt,
                0,
                "invalid timestamp"
            );

            assertEq(
                uint256(validatorInfo.status),
                uint256(ISymPod.VALIDATOR_STATUS.ACTIVE),
                "invalid validator state"
            );
        }
        
    }

    function test_CannotDoublyInitValidatorWC() external {
        createdHarnessPod.verifyValidatorWithdrawalCredentials(
            timestamp,
            validatorContainerProof,
            validatorProof
        );

        vm.expectRevert(ISymPod.SymPod__InvalidValidatorState.selector);
        createdHarnessPod.verifyValidatorWithdrawalCredentials(
            timestamp,
            validatorContainerProof,
            validatorProof
        );
    }

    function test_CannotVerifyInvalidExitEpoch() external {
        // @TODO get exited validator 
        validatorProof.validatorFields[0][BeaconChainProofs.VALIDATOR_EXIT_EPOCH_INDEX] = bytes32(uint256(4));
        vm.expectRevert(ISymPod.SymPod__InvalidValidatorExitEpoch.selector);
        createdHarnessPod.verifyValidatorWithdrawalCredentials(
            timestamp,
            validatorContainerProof,
            validatorProof
        );
    }

    function test_CannotVerifyInvalidActivationEpoch() external { 
        // @TODO get exited validator 
        validatorProof.validatorFields[0][BeaconChainProofs.VALIDATOR_ACTIVATION_EPOCH_INDEX] = bytes32(uint256(4));

        vm.expectRevert(ISymPod.SymPod__InvalidValidatorActivationEpoch.selector);
        createdHarnessPod.verifyValidatorWithdrawalCredentials(
            timestamp,
            validatorContainerProof,
            validatorProof
        );
    }

    function test_CannotVerifyInvalidWC() external {
        vm.expectRevert(ISymPod.SymPod__InvalidValidatorWithdrawalCredentials.selector);
        createdPod.verifyValidatorWithdrawalCredentials(
            timestamp,
            validatorContainerProof,
            validatorProof
        );
    }

}


contract SymPod__VerifyBalanceCheckpoints is BaseSymPodHarnessTest {

    uint64 timestamp;
    uint64 balanceCheckPointTimestamp;
    uint256 sizeOfValidators;
    BeaconChainProofs.ValidatorListContainerProof validatorContainerProof;
    BeaconChainProofs.ValidatorsMultiProof validatorProof;

    BeaconChainProofs.BalanceContainerProof balanceContainerProof;
    BeaconChainProofs.BalancesMultiProof validatorBalancesProof;

    bytes32 sampleValidatorPubKeyHash;

    function setUp() public override {
        super.setUp();

        string memory validatorFieldsProofFilePath = "./src/test/test-data/ValidatorFields-proof.json";
        string memory validatorListRootProofFilePath = "./src/test/test-data/ValidatorListRootProof-proof.json";

        string memory validatorBalanceContainerProofPath = "./src/test/test-data/BalanceListRootProof-proof.json";
        string memory validatorBalanceProofPath = "./src/test/test-data/ValidatorBalance-proof.json";

        proofParser.setJSONPath(validatorListRootProofFilePath);
        blockRoot = proofParser.getBlockRoot();


        validatorContainerProof = BeaconChainProofs.ValidatorListContainerProof({
            validatorListRoot: proofParser.getValidatorListRoot(),
            proof: proofParser.getValidatorListRootProofAgainstBlockRoot()
        });

        proofParser.setJSONPath(validatorFieldsProofFilePath);
        uint40[] memory validatorIndices = proofParser.getValidatorIndices();
        sizeOfValidators = validatorIndices.length;
        validatorProof = BeaconChainProofs.ValidatorsMultiProof({
            validatorFields: proofParser.getValidatorFields(validatorIndices.length),
            proof: proofParser.getValidatorFieldsProof(),
            validatorIndices: validatorIndices
        });
    
        proofParser.setJSONPath(validatorBalanceContainerProofPath);
        balanceContainerProof = BeaconChainProofs.BalanceContainerProof({
            balanceListRoot: proofParser.getBalanceListRoot(),
            proof: proofParser.getBalanceListRootProofAgainstBlockRoot()
        });

        proofParser.setJSONPath(validatorBalanceProofPath);
        bytes32[] memory validatorPubKeyHashes = proofParser.getValidatorPubKeyHashes();
        validatorBalancesProof = BeaconChainProofs.BalancesMultiProof({
            proof: proofParser.getValidatorBalancesProof(),
            validatorPubKeyHashes: validatorPubKeyHashes,
            validatorBalanceRoots: proofParser.getValidatorBalancesRoot()
        }); 

        sampleValidatorPubKeyHash = validatorPubKeyHashes[0];

        // verify wc
        vm.warp(10000 seconds);
        timestamp = uint64(block.timestamp - 1_000);
        beaconRootOracle.setBlockRoot(timestamp, blockRoot);
        /// verify Withdrawal credentials
        createdHarnessPod.verifyValidatorWithdrawalCredentials(
            timestamp,
            validatorContainerProof,
            validatorProof
        );       
    }

    function test_CannotVerifyForInactiveValidator() external {
        // set a validator status to inactive so it's skipped
        // during verification
        createdHarnessPod.changeValidatorStateToActive(sampleValidatorPubKeyHash);
        // call start check point
        // move time and set
        vm.warp(200_000 seconds);
        // balanceCheckPointTimestamp = uint64(block.timestamp - 1_000);
        beaconRootOracle.setBlockRoot(uint64(block.timestamp), blockRoot);

        vm.prank(podAdmin);
        createdHarnessPod.startCheckpoint(false);

        // verify balance checkpoint
        createdHarnessPod.verifyBalanceCheckPointProofs({
            balanceContainerProof: balanceContainerProof,
            validatorBalancesProof: validatorBalancesProof
        });
        // uint256 validatorSize = validatorBalancesProof.validatorPubKeyHashes.length;
        // this result checkpoint 
        ISymPod.Checkpoint memory currentCheckpoint = createdHarnessPod.getCurrentCheckpoint();

        assertEq(
            currentCheckpoint.proofsRemaining,
            1,
            "should have one proof remaining to be submitted"
        );
    }

    function test_CannotVerifyForAlreadyCheckpointedValidator() external {
        // set a validator status to inactive so it's skipped
        // during verification
        createdHarnessPod.changeValidatorStateToActive(sampleValidatorPubKeyHash);
        // call start check point
        // move time and set
        vm.warp(200_000 seconds);
        // balanceCheckPointTimestamp = uint64(block.timestamp - 1_000);
        beaconRootOracle.setBlockRoot(uint64(block.timestamp), blockRoot);

        vm.prank(podAdmin);
        createdHarnessPod.startCheckpoint(false);

        // verify balance checkpoint
        createdHarnessPod.verifyBalanceCheckPointProofs({
            balanceContainerProof: balanceContainerProof,
            validatorBalancesProof: validatorBalancesProof
        });

        // submitted twice
        // @TODO assert the events emitted that ValidatorCheckpointUpdate and ValidatorBalanceUpdated not included
        createdHarnessPod.verifyBalanceCheckPointProofs({
            balanceContainerProof: balanceContainerProof,
            validatorBalancesProof: validatorBalancesProof
        });

        // uint256 validatorSize = validatorBalancesProof.validatorPubKeyHashes.length;
        // this result checkpoint 
        ISymPod.Checkpoint memory currentCheckpoint = createdHarnessPod.getCurrentCheckpoint();

        assertEq(
            currentCheckpoint.proofsRemaining,
            1,
            "should have one proof remaining to be submitted"
        );
    }

    function test_CanVerifyBalanceCheckpoint() external {
        // call start check point
        // move time and set
        vm.warp(200_000 seconds);
        // balanceCheckPointTimestamp = uint64(block.timestamp - 1_000);
        beaconRootOracle.setBlockRoot(uint64(block.timestamp), blockRoot);

        vm.prank(podAdmin);
        createdHarnessPod.startCheckpoint(false);

        // submit balance checkpoint
        // @TODO add event checks
        createdHarnessPod.verifyBalanceCheckPointProofs({
            balanceContainerProof: balanceContainerProof,
            validatorBalancesProof: validatorBalancesProof
        });

    }

    function test_CanVerifyBalanceCheckpointWithPodBalance() external {
        // call start check point
        // move time and set
        vm.warp(200_000 seconds);
        // balanceCheckPointTimestamp = uint64(block.timestamp - 1_000);
        beaconRootOracle.setBlockRoot(uint64(block.timestamp), blockRoot);

        vm.prank(podAdmin);

        vm.deal(address(createdHarnessPod), 10 ether);
        createdHarnessPod.startCheckpoint(true);

        // submit balance checkpoint
        // @TODO add event checks
        createdHarnessPod.verifyBalanceCheckPointProofs({
            balanceContainerProof: balanceContainerProof,
            validatorBalancesProof: validatorBalancesProof
        });

    }

}


// One more test
contract SymPod__VerifyExpiredBalance is BaseSymPodHarnessTest {
    uint64 timestamp;
    uint256 sizeOfValidators;
    BeaconChainProofs.ValidatorListContainerProof validatorContainerProof;
    BeaconChainProofs.ValidatorProof validatorFieldsProof;

    bytes32 validatorPubKeyHash;

    function setUp() public override {
        super.setUp();

        string memory validatorFieldsProofFilePath = "./src/test/test-data/mainnet/slashed/ValidatorFields-proof_deneb_mainnet_slot_9575417_slashed.json";
        string memory validatorListRootProofFilePath = "./src/test/test-data/mainnet/slashed/ValidatorListRootProof-proof_deneb_mainnet_slot_9575417_slashed.json";

        proofParser.setJSONPath(validatorListRootProofFilePath);
        blockRoot = proofParser.getBlockRoot();

        vm.warp(10000 seconds);

        timestamp = uint64(block.timestamp - 1_000);

        validatorContainerProof = BeaconChainProofs.ValidatorListContainerProof({
            validatorListRoot: proofParser.getValidatorListRoot(),
            proof: proofParser.getValidatorListRootProofAgainstBlockRoot()
        });

        proofParser.setJSONPath(validatorFieldsProofFilePath);
        uint40[] memory validatorIndices = proofParser.getValidatorIndices();
        sizeOfValidators = validatorIndices.length;
        validatorFieldsProof = BeaconChainProofs.ValidatorProof({
            validatorFields: proofParser.getValidatorFields(validatorIndices.length),
            proof: proofParser.getValidatorFieldsProof(),
            validatorIndices: validatorIndices
        });

        beaconRootOracle.setBlockRoot(timestamp, blockRoot);
        beaconRootOracle.setBlockRoot(uint64(block.timestamp), blockRoot);

        validatorPubKeyHash = validatorFieldsProof.validatorFields[0][BeaconChainProofs.VALIDATOR_PUBKEY_INDEX];

    }

    function test_CannotVerifyExpiredBalanceIfValidatorNotActive() external {
        vm.expectRevert(ISymPod.SymPod__InvalidValidatorState.selector);
        createdHarnessPod.verifyExpiredBalance({
            beaconTimestamp: timestamp,
            validatorListRootProof: validatorContainerProof,
            validatorFieldsProof: validatorFieldsProof
        });
    }

    function test_CannotVerifyIfInvaldBeaconTimestamp() external {
        createdHarnessPod.changeValidatorLastCheckpointedAt(validatorPubKeyHash, timestamp + 10);

        vm.expectRevert(ISymPod.SymPod__InvalidBeaconTimestamp.selector);
        createdHarnessPod.verifyExpiredBalance({
            beaconTimestamp: timestamp,
            validatorListRootProof: validatorContainerProof,
            validatorFieldsProof: validatorFieldsProof
        });
    }

    function test_CannotVerifyIfValidatorNotSlashed() external {
        // vm.expectRevert(ISymPod.SymPod__InvalidValidatorState.selector);
        // use here
        
    }

    function test_verifyExpiredBalance() external {
        // we are proving only one validator
        createdHarnessPod.changeValidatorStateToActive(validatorPubKeyHash);

        // @TODO check created checkpoint events
        createdHarnessPod.verifyExpiredBalance({
            beaconTimestamp: timestamp,
            validatorListRootProof: validatorContainerProof,
            validatorFieldsProof: validatorFieldsProof
        });

    }
}