// SPDX-License-Identifier: Proprietary
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {ObolValidatorManager} from "src/ovm/ObolValidatorManager.sol";
import {ObolValidatorManagerFactory} from "src/ovm/ObolValidatorManagerFactory.sol";
import {IObolValidatorManager} from "src/interfaces/IObolValidatorManager.sol";
import {MockERC20} from "../utils/mocks/MockERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ObolValidatorManagerReentrancy} from "./ObolValidatorManagerReentrancy.sol";
import {SystemContractMock} from "./mocks/SystemContractMock.sol";
import {DepositContractMock} from "./mocks/DepositContractMock.sol";
import {IENSReverseRegistrar} from "../../interfaces/IENSReverseRegistrar.sol";

contract ObolValidatorManagerTest is Test {
  using SafeTransferLib for address;

  // Events from IObolValidatorManager interface - redeclared for testing
  event BeneficiaryUpdated(address indexed newBeneficiary);
  event RewardRecipientUpdated(address indexed newRewardRecipient);
  event PrincipalStakeAmountUpdated(uint256 newPrincipalStakeAmount, uint256 oldPrincipalStakeAmount);
  event Swept(address indexed beneficiary, uint256 indexed amount);
  event DistributeFunds(uint256 principalPayout, uint256 rewardPayout, uint256 pullOrPush);
  event RecoverNonOVMFunds(address indexed nonOVMToken, address indexed recipient, uint256 amount);
  event PullBalanceWithdrawn(address indexed account, uint256 amount);
  event ConsolidationRequested(bytes srcPubKey, bytes targetPubKey, uint256 indexed fee);
  event WithdrawalRequested(bytes pubkey, uint64 indexed amount, uint256 indexed fee);
  event UnsentExcessFee(address indexed excessFeeRecipient, uint256 indexed excessFee);
  event Transferred(address indexed newBeneficiary, address indexed newOwner);

  address public ENS_REVERSE_REGISTRAR = 0x084b1c3C81545d370f3634392De611CaaBFf8148;

  uint64 public constant BALANCE_CLASSIFICATION_THRESHOLD_GWEI = 16 ether / 1 gwei;
  uint256 public constant INITIAL_DEPOSIT_AMOUNT = 32 ether;

  ObolValidatorManagerFactory public ovmFactory;
  ObolValidatorManager ovmETH;
  ObolValidatorManager ovmETH_OR;

  SystemContractMock consolidationMock;
  SystemContractMock withdrawalMock;
  DepositContractMock depositMock;

  MockERC20 mERC20;

  address internal beneficiary;
  address internal rewardsRecipient;
  uint64 internal principalThreshold;

  function setUp() public {
    vm.mockCall(
      ENS_REVERSE_REGISTRAR,
      abi.encodeWithSelector(IENSReverseRegistrar.setName.selector),
      bytes.concat(bytes32(0))
    );
    vm.mockCall(
      ENS_REVERSE_REGISTRAR,
      abi.encodeWithSelector(IENSReverseRegistrar.claim.selector),
      bytes.concat(bytes32(0))
    );

    consolidationMock = new SystemContractMock(48 + 48);
    withdrawalMock = new SystemContractMock(48 + 8);
    depositMock = new DepositContractMock();

    ovmFactory = new ObolValidatorManagerFactory(
      address(consolidationMock),
      address(withdrawalMock),
      address(depositMock),
      "demo.obol.eth",
      ENS_REVERSE_REGISTRAR,
      address(this)
    );

    mERC20 = new MockERC20("demo", "DMT", 18);
    mERC20.mint(type(uint256).max);

    beneficiary = makeAddr("beneficiary");
    rewardsRecipient = makeAddr("rewardsRecipient");
    principalThreshold = BALANCE_CLASSIFICATION_THRESHOLD_GWEI;

    ovmETH = ovmFactory.createObolValidatorManager(
      address(this),
      beneficiary,
      rewardsRecipient,
      principalThreshold
    );
    ovmETH_OR = ovmFactory.createObolValidatorManager(
      address(this),
      beneficiary,
      rewardsRecipient,
      principalThreshold
    );

    ovmETH.deposit{value: INITIAL_DEPOSIT_AMOUNT}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));
    ovmETH_OR.deposit{value: INITIAL_DEPOSIT_AMOUNT}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));
  }

  function testDefaultParameters() public view {
    assertEq(ovmETH.getBeneficiary(), beneficiary, "invalid beneficiary recipient");
    assertEq(ovmETH.rewardRecipient(), rewardsRecipient, "invalid rewards recipient");
    assertEq(ovmETH.principalThreshold(), BALANCE_CLASSIFICATION_THRESHOLD_GWEI, "invalid principal threshold");
  }

  function testOwnerInitialization() public view {
    assertEq(ovmETH.owner(), address(this));
  }

  function testDeposit() public {
    uint256 depositMockBalance = address(depositMock).balance;
    uint256 amountOfPrincipalStake = ovmETH.amountOfPrincipalStake();
    uint256 depositAmount = 1 ether;
    vm.expectEmit(true, true, true, true);
    emit PrincipalStakeAmountUpdated(amountOfPrincipalStake + depositAmount, amountOfPrincipalStake);
    ovmETH.deposit{value: depositAmount}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));
    assertEq(address(depositMock).balance, depositMockBalance + depositAmount);
    assertEq(ovmETH.amountOfPrincipalStake(), amountOfPrincipalStake + depositAmount);
  }

  function testCannotDeposit() public {
    // unauthorized
    address _user = vm.addr(0x5);
    vm.deal(_user, 1 ether);
    ovmETH.grantRoles(_user, ovmETH.WITHDRAWAL_ROLE()); // unrelated role
    vm.startPrank(_user);
    vm.expectRevert(bytes4(0x82b42900));
    ovmETH.deposit{value: 1 ether}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));
    vm.stopPrank();

    // unauthorized for owner after renounce
    ovmETH.renounceOwnership();
    vm.expectRevert(bytes4(0x82b42900));
    ovmETH.deposit{value: 1 ether}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));
  }

  function testSetBeneficiaryRecipient() public {
    // initial recipient
    assertEq(ovmETH.getBeneficiary(), beneficiary, "invalid beneficiary recipient");

    address newRecipient = makeAddr("newRecipient");
    vm.expectEmit(true, true, true, true);
    emit BeneficiaryUpdated(newRecipient);
    ovmETH.setBeneficiary(newRecipient);
    assertEq(ovmETH.getBeneficiary(), newRecipient);
  }

  function testSetAmountOfPrincipalStake() public {
    uint256 newAmount = 1 ether;
    uint256 amountOfPrincipalStake = ovmETH.amountOfPrincipalStake();
    vm.expectEmit(true, true, true, true);
    emit PrincipalStakeAmountUpdated(newAmount, amountOfPrincipalStake);
    ovmETH.setAmountOfPrincipalStake(newAmount);
    assertEq(ovmETH.amountOfPrincipalStake(), newAmount);

    // zero value must be allowed
    newAmount = 0;
    ovmETH.setAmountOfPrincipalStake(newAmount);
    assertEq(ovmETH.amountOfPrincipalStake(), newAmount);

    // no max cap
    newAmount = type(uint256).max;
    ovmETH.setAmountOfPrincipalStake(newAmount);
    assertEq(ovmETH.amountOfPrincipalStake(), newAmount);
  }

  function testCannot_setBeneficiaryRecipient() public {
    // zero address
    vm.expectRevert(IObolValidatorManager.InvalidRequest_Params.selector);
    ovmETH.setBeneficiary(address(0));

    // unauthorized
    address _user = vm.addr(0x2);
    ovmETH.grantRoles(_user, ovmETH.WITHDRAWAL_ROLE()); // unrelated role
    vm.startPrank(_user);
    vm.expectRevert(bytes4(0x82b42900));
    ovmETH.setBeneficiary(makeAddr("noaccess"));
    vm.stopPrank();

    // unauthorized for owner after renounce
    ovmETH.renounceOwnership();
    vm.expectRevert(bytes4(0x82b42900));
    ovmETH.setBeneficiary(makeAddr("noaccess"));
  }

  function testSetRewardRecipient() public {
    // initial recipient
    assertEq(ovmETH.rewardRecipient(), rewardsRecipient, "invalid rewards recipient");

    address newRecipient = makeAddr("newRecipient");
    vm.expectEmit(true, true, true, true);
    emit RewardRecipientUpdated(newRecipient);
    ovmETH.setRewardRecipient(newRecipient);
    assertEq(ovmETH.rewardRecipient(), newRecipient);
  }

  function testCannot_setRewardRecipient() public {
    // zero address
    vm.expectRevert(IObolValidatorManager.InvalidRequest_Params.selector);
    ovmETH.setRewardRecipient(address(0));

    // unauthorized
    address _user = vm.addr(0x2);
    ovmETH.grantRoles(_user, ovmETH.WITHDRAWAL_ROLE()); // unrelated role
    vm.startPrank(_user);
    vm.expectRevert(bytes4(0x82b42900));
    ovmETH.setRewardRecipient(makeAddr("noaccess"));
    vm.stopPrank();

    // unauthorized for owner after renounce
    ovmETH.renounceOwnership();
    vm.expectRevert(bytes4(0x82b42900));
    ovmETH.setRewardRecipient(makeAddr("noaccess"));
  }

  function testSweep_toDefaultBeneficiary() public {
    // Send enough ETH to the contract (>= principalThreshold) and distribute as pull
    uint256 sweepAmount = 20 ether; // Above 16 ether threshold
    address(ovmETH).safeTransferETH(sweepAmount);
    ovmETH.distributeFundsPull();

    uint256 initialBeneficiaryBalance = beneficiary.balance;
    uint256 initialPullBalance = ovmETH.getPullBalance(beneficiary);
    uint256 initialFundsPending = ovmETH.fundsPendingWithdrawal();

    // Sweep to default beneficiary (address(0) means use beneficiary)
    vm.expectEmit(true, true, true, true);
    emit Swept(beneficiary, sweepAmount);
    ovmETH.sweep(address(0), sweepAmount);

    assertEq(beneficiary.balance, initialBeneficiaryBalance + sweepAmount);
    assertEq(ovmETH.getPullBalance(beneficiary), initialPullBalance - sweepAmount);
    assertEq(ovmETH.fundsPendingWithdrawal(), initialFundsPending - sweepAmount);
  }

  function testSweep_toSpecificAddress() public {
    // Send enough ETH to the contract (>= principalThreshold) and distribute as pull
    uint256 sweepAmount = 18 ether; // Above 16 ether threshold
    address(ovmETH).safeTransferETH(sweepAmount);
    ovmETH.distributeFundsPull();

    address customRecipient = makeAddr("customRecipient");
    uint256 initialRecipientBalance = customRecipient.balance;
    uint256 initialPullBalance = ovmETH.getPullBalance(beneficiary);
    uint256 initialFundsPending = ovmETH.fundsPendingWithdrawal();

    // Sweep to custom address (requires owner)
    vm.expectEmit(true, true, true, true);
    emit Swept(customRecipient, sweepAmount);
    ovmETH.sweep(customRecipient, sweepAmount);

    assertEq(customRecipient.balance, initialRecipientBalance + sweepAmount);
    assertEq(ovmETH.getPullBalance(beneficiary), initialPullBalance - sweepAmount);
    assertEq(ovmETH.fundsPendingWithdrawal(), initialFundsPending - sweepAmount);
  }

  function testSweep_allFunds() public {
    // Send enough ETH to the contract (>= principalThreshold) and distribute as pull
    address(ovmETH).safeTransferETH(25 ether);
    ovmETH.distributeFundsPull();

    uint256 pullBalanceBeneficiary = ovmETH.getPullBalance(beneficiary);
    uint256 initialBeneficiaryBalance = beneficiary.balance;
    uint256 initialFundsPending = ovmETH.fundsPendingWithdrawal();

    // Sweep all funds (amount = 0 means sweep all from pullBalances[principalRecipient])
    vm.expectEmit(true, true, true, true);
    emit Swept(beneficiary, pullBalanceBeneficiary);
    ovmETH.sweep(address(0), 0);

    assertEq(beneficiary.balance, initialBeneficiaryBalance + pullBalanceBeneficiary);
    assertEq(ovmETH.getPullBalance(beneficiary), 0);
    assertEq(ovmETH.fundsPendingWithdrawal(), initialFundsPending - pullBalanceBeneficiary);
  }

  function testSweep_partialAmount() public {
    // Send enough ETH to the contract (>= principalThreshold) and distribute as pull
    address(ovmETH).safeTransferETH(30 ether);
    ovmETH.distributeFundsPull();

    uint256 sweepAmount = 20 ether;
    uint256 initialBeneficiaryBalance = beneficiary.balance;
    uint256 initialPullBalance = ovmETH.getPullBalance(beneficiary);
    uint256 initialFundsPending = ovmETH.fundsPendingWithdrawal();

    // Sweep partial amount
    vm.expectEmit(true, true, true, true);
    emit Swept(beneficiary, sweepAmount);
    ovmETH.sweep(address(0), sweepAmount);

    assertEq(beneficiary.balance, initialBeneficiaryBalance + sweepAmount);
    assertEq(ovmETH.getPullBalance(beneficiary), initialPullBalance - sweepAmount);
    assertEq(ovmETH.fundsPendingWithdrawal(), initialFundsPending - sweepAmount);
  }

  function testCannot_sweepMoreThanBalance() public {
    // Send enough ETH to the contract (>= principalThreshold) and distribute as pull
    address(ovmETH).safeTransferETH(20 ether);
    ovmETH.distributeFundsPull();

    uint256 beneficiaryPullBalance = ovmETH.getPullBalance(beneficiary);

    // Try to sweep more than available in pullBalances[principalRecipient]
    vm.expectRevert(IObolValidatorManager.InvalidRequest_Params.selector);
    ovmETH.sweep(address(0), beneficiaryPullBalance + 1 ether);
  }

  function testCannot_sweepMoreThanPullBalance() public {
    // Send some ETH to the contract and distribute as pull
    address(ovmETH).safeTransferETH(50 ether);
    ovmETH.distributeFundsPull();

    uint256 beneficiaryPullBalance = ovmETH.getPullBalance(beneficiary);
    
    // Try to sweep more than pullBalance for principalRecipient
    vm.expectRevert(IObolValidatorManager.InvalidRequest_Params.selector);
    ovmETH.sweep(address(0), beneficiaryPullBalance + 1 ether);
  }

  function testCannot_sweepAfterRenounceOwnership() public {
    // Renounce ownership
    ovmETH.renounceOwnership();

    // Send enough ETH to the contract (>= principalThreshold) and distribute as pull
    address(ovmETH).safeTransferETH(20 ether);
    ovmETH.distributeFundsPull();

    address customRecipient = makeAddr("customRecipient");

    // Try to sweep to custom address after renouncing ownership (should fail)
    vm.expectRevert(bytes4(0x82b42900)); // Unauthorized
    ovmETH.sweep(customRecipient, 5 ether);
  }

  function testCannot_sweepToCustomAddressAsNonOwner() public {
    // Send enough ETH to the contract (>= principalThreshold) and distribute as pull
    address(ovmETH).safeTransferETH(20 ether);
    ovmETH.distributeFundsPull();

    address customRecipient = makeAddr("customRecipient");

    // Try to sweep to custom address as non-owner (should fail on _checkOwner)
    address _user = vm.addr(0x9);
    vm.startPrank(_user);
    vm.expectRevert(bytes4(0x82b42900)); // Unauthorized
    ovmETH.sweep(customRecipient, 5 ether);
    vm.stopPrank();
  }

  function testSweep_asNonOwnerToDefaultBeneficiary() public {
    // Send enough ETH to the contract (>= principalThreshold) and distribute as pull
    uint256 sweepAmount = 20 ether; // Above 16 ether threshold
    address(ovmETH).safeTransferETH(sweepAmount);
    ovmETH.distributeFundsPull();

    // Non-owner CAN sweep to default beneficiary (address(0)) without being owner
    address _user = vm.addr(0x9);
    vm.startPrank(_user);

    uint256 initialBeneficiaryBalance = beneficiary.balance;
    uint256 initialPullBalance = ovmETH.getPullBalance(beneficiary);
    uint256 initialFundsPending = ovmETH.fundsPendingWithdrawal();

    vm.expectEmit(true, true, true, true);
    emit Swept(beneficiary, sweepAmount);
    ovmETH.sweep(address(0), sweepAmount);

    assertEq(beneficiary.balance, initialBeneficiaryBalance + sweepAmount);
    assertEq(ovmETH.getPullBalance(beneficiary), initialPullBalance - sweepAmount);
    assertEq(ovmETH.fundsPendingWithdrawal(), initialFundsPending - sweepAmount);

    vm.stopPrank();
  }

  function testCannot_consolidate() public {
    // Unauthorized
    address _user = vm.addr(0x2);
    ovmETH.grantRoles(_user, ovmETH.WITHDRAWAL_ROLE());
    vm.deal(_user, type(uint256).max);
    vm.startPrank(_user);
    vm.expectRevert(bytes4(0x82b42900));
    IObolValidatorManager.ConsolidationRequest[] memory requests = new IObolValidatorManager.ConsolidationRequest[](1);
    requests[0] = IObolValidatorManager.ConsolidationRequest({srcPubKeys: new bytes[](1), targetPubKey: new bytes(48)});
    ovmETH.consolidate{value: 1 ether}(requests, 1 ether, _user);
    vm.stopPrank();

    // Empty source array
    vm.expectRevert(IObolValidatorManager.InvalidRequest_Params.selector);
    bytes[] memory empty = new bytes[](0);
    IObolValidatorManager.ConsolidationRequest[] memory emptyRequests = new IObolValidatorManager.ConsolidationRequest[](1);
    emptyRequests[0] = IObolValidatorManager.ConsolidationRequest({srcPubKeys: empty, targetPubKey: new bytes(48)});
    ovmETH.consolidate{value: 1 ether}(emptyRequests, 1 ether, address(this));

    // Not enough fee (1 wei is the minimum fee)
    vm.expectRevert(IObolValidatorManager.InvalidRequest_NotEnoughFee.selector);
    bytes[] memory single = new bytes[](1);
    single[0] = new bytes(48);
    IObolValidatorManager.ConsolidationRequest[] memory singleRequests = new IObolValidatorManager.ConsolidationRequest[](1);
    singleRequests[0] = IObolValidatorManager.ConsolidationRequest({srcPubKeys: single, targetPubKey: new bytes(48)});
    ovmETH.consolidate{value: 0}(singleRequests, 100 wei, address(this));

    // Failed get_fee() request
    uint256 realFee = consolidationMock.fakeExponential(0);
    consolidationMock.setFailNextFeeRequest(true);
    vm.expectRevert(IObolValidatorManager.InvalidRequest_SystemGetFee.selector);
    ovmETH.consolidate{value: realFee}(singleRequests, realFee, address(this));
    consolidationMock.setFailNextFeeRequest(false);

    // Failed add_request() request
    consolidationMock.setFailNextAddRequest(true);
    vm.expectRevert(IObolValidatorManager.InvalidConsolidation_Failed.selector);
    ovmETH.consolidate{value: realFee}(singleRequests, realFee, address(this));
    consolidationMock.setFailNextAddRequest(false);

    // Maximum number of source pubkeys is 63
    vm.expectRevert(IObolValidatorManager.InvalidRequest_Params.selector);
    bytes[] memory batch64 = new bytes[](64);
    IObolValidatorManager.ConsolidationRequest[] memory batch64Requests = new IObolValidatorManager.ConsolidationRequest[](1);
    batch64Requests[0] = IObolValidatorManager.ConsolidationRequest({srcPubKeys: batch64, targetPubKey: new bytes(48)});
    ovmETH.consolidate{value: realFee}(batch64Requests, realFee, address(this));
  }

  function testSingleConsolidation() public {
    bytes[] memory srcPubkeys = new bytes[](1);
    bytes memory srcPubkey = new bytes(48);
    bytes memory dstPubkey = new bytes(48);
    for (uint256 i = 0; i < 48; i++) {
      srcPubkey[i] = bytes1(0xAB);
      dstPubkey[i] = bytes1(0xCD);
    }
    srcPubkeys[0] = srcPubkey;

    address _user = vm.addr(0x1);
    ovmETH.grantRoles(_user, ovmETH.CONSOLIDATION_ROLE());
    uint256 realFee = consolidationMock.fakeExponential(0);

    vm.deal(_user, 1 ether);
    vm.startPrank(_user);
    vm.expectEmit(true, true, true, true);
    emit ConsolidationRequested(srcPubkey, dstPubkey, realFee);
    IObolValidatorManager.ConsolidationRequest[] memory consolidationRequests = new IObolValidatorManager.ConsolidationRequest[](1);
    consolidationRequests[0] = IObolValidatorManager.ConsolidationRequest({srcPubKeys: srcPubkeys, targetPubKey: dstPubkey});
    ovmETH.consolidate{value: 100 wei}(consolidationRequests, 100 wei, _user);
    vm.stopPrank();

    bytes memory requestData = bytes.concat(srcPubkey, dstPubkey);
    bytes[] memory requestsMade = consolidationMock.getRequests();
    assertEq(requestsMade.length, 1);
    assertEq(requestsMade[0], requestData);
    assertEq(address(consolidationMock).balance, realFee);
    assertEq(_user.balance, 1 ether - realFee);
  }

  function testBatchConsolidation() public {
    uint256 numRequests = 10;
    uint256 expectedTotalFee;
    uint256 excessFee = 100 wei;
    bytes[] memory srcPubkeys = new bytes[](numRequests);
    bytes memory dstPubkey = new bytes(48);

    for (uint8 i = 0; i < numRequests; i++) {
      expectedTotalFee += consolidationMock.fakeExponential(i);

      bytes memory srcPubkey = new bytes(48);
      for (uint8 j = 0; j < 48; j++) {
        srcPubkey[i] = bytes1(i + 1);
        dstPubkey[i] = bytes1(0xFF);
      }
      srcPubkeys[i] = srcPubkey;
    }

    address _user = vm.addr(0x1);
    ovmETH.grantRoles(_user, ovmETH.CONSOLIDATION_ROLE());

    vm.deal(_user, expectedTotalFee + excessFee);
    vm.startPrank(_user);
    IObolValidatorManager.ConsolidationRequest[] memory batchRequests = new IObolValidatorManager.ConsolidationRequest[](1);
    batchRequests[0] = IObolValidatorManager.ConsolidationRequest({srcPubKeys: srcPubkeys, targetPubKey: dstPubkey});
    ovmETH.consolidate{value: expectedTotalFee}(batchRequests, type(uint256).max, _user);
    vm.stopPrank();

    bytes[] memory requestsMade = consolidationMock.getRequests();
    assertEq(requestsMade.length, numRequests);
    assertEq(_user.balance, excessFee);
    assertEq(address(consolidationMock).balance, expectedTotalFee);
    for (uint256 i; i < numRequests; i++) {
      bytes memory requestData = bytes.concat(srcPubkeys[i], dstPubkey);
      assertEq(requestsMade[i], requestData);
    }
  }

  function testCannot_withdraw() public {
    // Unauthorized
    address _user = vm.addr(0x2);
    ovmETH.grantRoles(_user, ovmETH.CONSOLIDATION_ROLE());
    vm.deal(_user, type(uint256).max);
    vm.startPrank(_user);
    vm.expectRevert(bytes4(0x82b42900));
    ovmETH.withdraw{value: 1 ether}(new bytes[](1), new uint64[](1), 1 ether, _user);
    vm.stopPrank();

    uint64[] memory amounts = new uint64[](1);
    bytes[] memory single = new bytes[](1);
    single[0] = new bytes(48);

    // Inequal array lengths
    vm.expectRevert(IObolValidatorManager.InvalidRequest_Params.selector);
    bytes[] memory empty = new bytes[](0);
    ovmETH.withdraw{value: 1 ether}(empty, amounts, 1 ether, address(this));

    // Not enough fee (1 wei is the minimum fee)
    uint256 validAmount = principalThreshold;
    amounts[0] = uint64(validAmount);
    vm.expectRevert(IObolValidatorManager.InvalidRequest_NotEnoughFee.selector);
    ovmETH.withdraw{value: 0}(single, amounts, 100 wei, address(this));

    // Failed get_fee() request
    uint256 realFee = withdrawalMock.fakeExponential(0);
    amounts[0] = uint64(validAmount);
    withdrawalMock.setFailNextFeeRequest(true);
    vm.expectRevert(IObolValidatorManager.InvalidRequest_SystemGetFee.selector);
    ovmETH.withdraw{value: realFee}(single, amounts, realFee, address(this));
    withdrawalMock.setFailNextFeeRequest(false);

    // Failed add_request() request
    withdrawalMock.setFailNextAddRequest(true);
    vm.expectRevert(IObolValidatorManager.InvalidWithdrawal_Failed.selector);
    ovmETH.withdraw{value: realFee}(single, amounts, realFee, address(this));
    withdrawalMock.setFailNextAddRequest(false);
  }

  function testSingleWithdrawal() public {
    bytes[] memory pubkeys = new bytes[](1);
    uint64[] memory amounts = new uint64[](1);
    bytes memory pubkey = new bytes(48);
    uint64 amount = uint64(principalThreshold);
    for (uint256 i = 0; i < 48; i++) {
      pubkey[i] = bytes1(0xAB);
    }
    pubkeys[0] = pubkey;
    amounts[0] = amount;

    address _user = vm.addr(0x2);
    ovmETH.grantRoles(_user, ovmETH.WITHDRAWAL_ROLE());
    uint256 realFee = withdrawalMock.fakeExponential(0);

    vm.deal(_user, 1 ether);
    vm.startPrank(_user);
    vm.expectEmit(true, true, true, true);
    emit WithdrawalRequested(pubkey, amount, realFee);
    ovmETH.withdraw{value: 100 wei}(pubkeys, amounts, 100 wei, _user);
    vm.stopPrank();

    bytes memory requestData = abi.encodePacked(pubkey, amount);
    bytes[] memory requestsMade = withdrawalMock.getRequests();
    assertEq(requestsMade.length, 1);
    assertEq(requestsMade[0], requestData);
    assertEq(address(withdrawalMock).balance, realFee);
    assertEq(_user.balance, 1 ether - realFee);
  }

  function testBatchWithdrawal() public {
    uint256 excessFee = 100 wei;
    uint256 numRequests = 10;
    bytes[] memory pubkeys = new bytes[](numRequests);
    uint64[] memory amounts = new uint64[](numRequests);

    // New implementation uses a single fee for all requests (fee at the start)
    uint256 feePerRequest = withdrawalMock.fakeExponential(0);
    uint256 expectedTotalFee = feePerRequest * numRequests;

    for (uint8 i = 0; i < numRequests; i++) {
      bytes memory pubkey = new bytes(48);
      for (uint8 j = 0; j < 48; j++) {
        pubkey[i] = bytes1(i + 1);
      }
      pubkeys[i] = pubkey;
      amounts[i] = uint64(principalThreshold + i);
    }

    address _user = vm.addr(0x1);
    ovmETH.grantRoles(_user, ovmETH.WITHDRAWAL_ROLE());

    vm.deal(_user, expectedTotalFee + excessFee);
    vm.startPrank(_user);
    ovmETH.withdraw{value: expectedTotalFee}(pubkeys, amounts, feePerRequest, _user);
    vm.stopPrank();

    bytes[] memory requestsMade = withdrawalMock.getRequests();
    assertEq(requestsMade.length, numRequests);
    assertEq(_user.balance, excessFee);
    assertEq(address(withdrawalMock).balance, expectedTotalFee);
    for (uint256 i; i < numRequests; i++) {
      bytes memory requestData = abi.encodePacked(pubkeys[i], amounts[i]);
      assertEq(requestsMade[i], requestData);
    }
  }

  function testReceiveETH() public {
    address(ovmETH).safeTransferETH(1 ether);
    assertEq(address(ovmETH).balance, 1 ether);
  }

  function testReceiveTransfer() public {
    payable(address(ovmETH)).transfer(1 ether);
    assertEq(address(ovmETH).balance, 1 ether);
  }

  function testReceiveERC20() public {
    address(mERC20).safeTransfer(address(ovmETH), 1e10);
    assertEq(mERC20.balanceOf(address(ovmETH)), 1e10);
  }

  function testCan_recoverNonOVMFundsToRecipient() public {
    address(ovmETH).safeTransferETH(1 ether);
    address(mERC20).safeTransfer(address(ovmETH), 1 ether);
    address(ovmETH_OR).safeTransferETH(1 ether);
    address(mERC20).safeTransfer(address(ovmETH_OR), 1 ether);

    address _user = vm.addr(0x7);
    ovmETH.grantRoles(_user, ovmETH.RECOVER_FUNDS_ROLE());
    ovmETH_OR.grantRoles(_user, ovmETH_OR.RECOVER_FUNDS_ROLE());
    vm.deal(_user, 1 ether);
    vm.startPrank(_user);

    vm.expectEmit(true, true, true, true);
    address recoveryAddress = makeAddr("recoveryAddress");
    emit RecoverNonOVMFunds(address(mERC20), recoveryAddress, 1 ether);
    ovmETH.recoverFunds(address(mERC20), recoveryAddress);
    assertEq(address(ovmETH).balance, 1 ether);
    assertEq(mERC20.balanceOf(address(ovmETH)), 0 ether);
    assertEq(mERC20.balanceOf(recoveryAddress), 1 ether);

    vm.expectEmit(true, true, true, true);
    emit RecoverNonOVMFunds(address(mERC20), beneficiary, 1 ether);
    ovmETH_OR.recoverFunds(address(mERC20), beneficiary);
    assertEq(address(ovmETH_OR).balance, 1 ether);
    assertEq(mERC20.balanceOf(address(ovmETH_OR)), 0 ether);
    assertEq(mERC20.balanceOf(beneficiary), 1 ether);

    vm.stopPrank();

    address(mERC20).safeTransfer(address(ovmETH_OR), 1 ether);

    vm.expectEmit(true, true, true, true);
    emit RecoverNonOVMFunds(address(mERC20), rewardsRecipient, 1 ether);
    ovmETH_OR.recoverFunds(address(mERC20), rewardsRecipient);
    assertEq(address(ovmETH_OR).balance, 1 ether);
    assertEq(mERC20.balanceOf(address(ovmETH_OR)), 0 ether);
    assertEq(mERC20.balanceOf(rewardsRecipient), 1 ether);
  }

  function testCannot_recoverFundsToNonRecipient() public {
    address _user = vm.addr(0x7);
    ovmETH.grantRoles(_user, ovmETH.SET_BENEFICIARY_ROLE()); // unrelated role
    vm.startPrank(_user);

    vm.expectRevert(bytes4(0x82b42900)); // unauthorized
    ovmETH.recoverFunds(address(mERC20), address(1));

    vm.stopPrank();
  }

  function test_WithdrawZeroBalance() public {
    address account = vm.addr(0x100);
    
    // Record logs to check no Withdrawal event is emitted
    vm.recordLogs();
    ovmETH.withdrawPullBalance(account);
    
    // Get all emitted events
    Vm.Log[] memory logs = vm.getRecordedLogs();
    
    // Assert no events were emitted (or verify no Withdrawal events specifically)
    assertEq(logs.length, 0, "No events should be emitted for zero balance withdrawal");
  }

  function testCan_distributeToNoRecipients() public {
    ovmETH.distributeFunds();
    assertEq(beneficiary.balance, 0 ether);
  }

  function testCan_emitOnDistributeToNoRecipients() public {
    uint256 principalPayout;
    uint256 rewardPayout;

    vm.expectEmit(true, true, true, true);
    emit DistributeFunds(principalPayout, rewardPayout, 0);
    ovmETH.distributeFunds();
  }

  function testCan_distributeToSecondRecipient() public {
    address(ovmETH).safeTransferETH(1 ether);

    uint256 rewardPayout = 1 ether;
    uint256 principalPayout;

    vm.expectEmit(true, true, true, true);
    emit DistributeFunds(principalPayout, rewardPayout, 0);
    ovmETH.distributeFunds();
    assertEq(address(ovmETH).balance, 0 ether);
    assertEq(rewardsRecipient.balance, 1 ether);

    rewardPayout = 0;
    vm.expectEmit(true, true, true, true);
    emit DistributeFunds(principalPayout, rewardPayout, 0);
    ovmETH.distributeFunds();
    assertEq(address(ovmETH).balance, 0 ether);
    assertEq(beneficiary.balance, 0 ether);
    assertEq(rewardsRecipient.balance, 1 ether);
  }

  function testCan_distributeMultipleDepositsTorewardsRecipient() public {
    address(ovmETH).safeTransferETH(0.5 ether);
    ovmETH.distributeFunds();
    assertEq(address(ovmETH).balance, 0 ether);
    assertEq(rewardsRecipient.balance, 0.5 ether);

    address(ovmETH).safeTransferETH(0.5 ether);
    ovmETH.distributeFunds();
    assertEq(address(ovmETH).balance, 0 ether);
    assertEq(rewardsRecipient.balance, 1 ether);
  }

  function testCan_distributeToBothRecipients() public {
    // First deposit of 32eth is done in setUp()
    uint256 secondDeposit = 64 ether;
    ovmETH.deposit{value: secondDeposit}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));
    uint256 rewardPayout = 4 ether;
    address(ovmETH).safeTransferETH(INITIAL_DEPOSIT_AMOUNT + secondDeposit + rewardPayout);

    vm.expectEmit(true, true, true, true);
    emit PrincipalStakeAmountUpdated(0, INITIAL_DEPOSIT_AMOUNT + secondDeposit);
    vm.expectEmit(true, true, true, true);
    emit DistributeFunds(INITIAL_DEPOSIT_AMOUNT + secondDeposit, rewardPayout, 0);
    ovmETH.distributeFunds();
    assertEq(address(ovmETH).balance, 0 ether);
    assertEq(beneficiary.balance, INITIAL_DEPOSIT_AMOUNT + secondDeposit);
    assertEq(rewardsRecipient.balance, rewardPayout);
  }

  function testCan_distributeDirectDepositsAsReward() public {
    // First deposit of 32eth is done in setUp()
    uint256 secondDeposit = 64 ether;
    uint256 rewardPayout = 4 ether;
    address(ovmETH).safeTransferETH(INITIAL_DEPOSIT_AMOUNT + secondDeposit + rewardPayout);

    vm.expectEmit(true, true, true, true);
    // Second deposit is classified as reward, because we did not call OVM.deposit()
    emit DistributeFunds(INITIAL_DEPOSIT_AMOUNT, secondDeposit + rewardPayout, 0);
    ovmETH.distributeFunds();
    assertEq(address(ovmETH).balance, 0 ether);
    assertEq(beneficiary.balance, INITIAL_DEPOSIT_AMOUNT);
    assertEq(rewardsRecipient.balance, rewardPayout + secondDeposit);
  }

  function testCan_distributeMultipleDepositsToBeneficiaryRecipient() public {
    address(ovmETH).safeTransferETH(16 ether);
    ovmETH.distributeFunds();

    address(ovmETH).safeTransferETH(16 ether);
    ovmETH.distributeFunds();

    assertEq(address(ovmETH).balance, 0 ether);
    assertEq(beneficiary.balance, 32 ether);
    assertEq(rewardsRecipient.balance, 0 ether);
  }

  function testCannot_distributeTooMuch() public {
    vm.deal(address(ovmETH), type(uint128).max);
    ovmETH.distributeFunds();
    vm.deal(address(ovmETH), 1);

    vm.deal(address(ovmETH), type(uint136).max);
    vm.expectRevert(IObolValidatorManager.InvalidDistribution_TooLarge.selector);
    ovmETH.distributeFunds();

    vm.expectRevert(IObolValidatorManager.InvalidDistribution_TooLarge.selector);
    ovmETH.distributeFundsPull();
  }

  function testCannot_reenterOVM() public {
    ObolValidatorManagerReentrancy re = new ObolValidatorManagerReentrancy();

    ovmETH = ovmFactory.createObolValidatorManager(address(this), address(re), rewardsRecipient, 1e9);
    ovmETH.deposit{value: 1 ether}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));
    address(ovmETH).safeTransferETH(33 ether);

    vm.expectRevert(SafeTransferLib.ETHTransferFailed.selector);
    ovmETH.distributeFunds();

    assertEq(address(ovmETH).balance, 33 ether);
    assertEq(address(re).balance, 0 ether);
    assertEq(address(0).balance, 0 ether);
  }

  function testCan_distributeToPullFlow() public {
    // test eth
    address(ovmETH).safeTransferETH(36 ether);
    ovmETH.distributeFundsPull();

    assertEq(address(ovmETH).balance, 36 ether);
    assertEq(beneficiary.balance, 0 ether);
    assertEq(rewardsRecipient.balance, 0 ether);

    assertEq(ovmETH.getPullBalance(beneficiary), 32 ether);
    assertEq(ovmETH.getPullBalance(rewardsRecipient), 4 ether);

    assertEq(ovmETH.fundsPendingWithdrawal(), 36 ether);

    ovmETH.withdrawPullBalance(rewardsRecipient);

    assertEq(address(ovmETH).balance, 32 ether);
    assertEq(beneficiary.balance, 0);
    assertEq(rewardsRecipient.balance, 4 ether);

    assertEq(ovmETH.getPullBalance(beneficiary), 32 ether);
    assertEq(ovmETH.getPullBalance(rewardsRecipient), 0);

    assertEq(ovmETH.fundsPendingWithdrawal(), 32 ether);

    ovmETH.withdrawPullBalance(beneficiary);

    assertEq(address(ovmETH).balance, 0 ether);
    assertEq(beneficiary.balance, 32 ether);
    assertEq(rewardsRecipient.balance, 4 ether);

    assertEq(ovmETH.getPullBalance(beneficiary), 0);
    assertEq(ovmETH.getPullBalance(rewardsRecipient), 0);

    assertEq(ovmETH.fundsPendingWithdrawal(), 0 ether);
  }

  function testCan_distributePushAndPull() public {
    // test eth
    address(ovmETH).safeTransferETH(0.5 ether);
    assertEq(address(ovmETH).balance, 0.5 ether, "2/incorrect balance");

    ovmETH.distributeFunds();

    assertEq(address(ovmETH).balance, 0, "3/incorrect balance");
    assertEq(beneficiary.balance, 0 ether);
    assertEq(rewardsRecipient.balance, 0.5 ether);

    assertEq(ovmETH.getPullBalance(beneficiary), 0 ether);
    assertEq(ovmETH.getPullBalance(rewardsRecipient), 0 ether);

    assertEq(ovmETH.fundsPendingWithdrawal(), 0 ether);

    address(ovmETH).safeTransferETH(1 ether);
    assertEq(address(ovmETH).balance, 1 ether);

    ovmETH.distributeFundsPull();

    assertEq(address(ovmETH).balance, 1 ether);
    assertEq(beneficiary.balance, 0 ether);
    assertEq(rewardsRecipient.balance, 0.5 ether);

    assertEq(ovmETH.getPullBalance(beneficiary), 0 ether);
    assertEq(ovmETH.getPullBalance(rewardsRecipient), 1 ether);

    assertEq(ovmETH.fundsPendingWithdrawal(), 1 ether);

    ovmETH.distributeFunds();

    assertEq(address(ovmETH).balance, 1 ether);
    assertEq(beneficiary.balance, 0 ether);
    assertEq(rewardsRecipient.balance, 0.5 ether);

    assertEq(ovmETH.getPullBalance(beneficiary), 0);
    assertEq(ovmETH.getPullBalance(rewardsRecipient), 1 ether);

    assertEq(ovmETH.fundsPendingWithdrawal(), 1 ether);

    ovmETH.distributeFundsPull();

    assertEq(address(ovmETH).balance, 1 ether);
    assertEq(beneficiary.balance, 0 ether);
    assertEq(rewardsRecipient.balance, 0.5 ether);

    assertEq(ovmETH.getPullBalance(beneficiary), 0);
    assertEq(ovmETH.getPullBalance(rewardsRecipient), 1 ether);

    assertEq(ovmETH.fundsPendingWithdrawal(), 1 ether);

    address(ovmETH).safeTransferETH(1 ether);
    assertEq(address(ovmETH).balance, 2 ether);

    ovmETH.distributeFunds();

    assertEq(address(ovmETH).balance, 1 ether);
    assertEq(beneficiary.balance, 0);
    assertEq(rewardsRecipient.balance, 1.5 ether);

    assertEq(ovmETH.getPullBalance(beneficiary), 0 ether);
    assertEq(ovmETH.getPullBalance(rewardsRecipient), 1 ether);

    assertEq(ovmETH.fundsPendingWithdrawal(), 1 ether);

    ovmETH.withdrawPullBalance(rewardsRecipient);

    assertEq(address(ovmETH).balance, 0 ether);
    assertEq(beneficiary.balance, 0);
    assertEq(rewardsRecipient.balance, 2.5 ether);

    assertEq(ovmETH.getPullBalance(beneficiary), 0 ether);
    assertEq(ovmETH.getPullBalance(rewardsRecipient), 0 ether);

    assertEq(ovmETH.fundsPendingWithdrawal(), 0);

    address(ovmETH).safeTransferETH(1 ether);
    ovmETH.withdrawPullBalance(rewardsRecipient);

    assertEq(address(ovmETH).balance, 1 ether);
    assertEq(beneficiary.balance, 0 ether);
    assertEq(rewardsRecipient.balance, 2.5 ether);

    assertEq(ovmETH.getPullBalance(beneficiary), 0 ether);
    assertEq(ovmETH.getPullBalance(rewardsRecipient), 0 ether);

    assertEq(ovmETH.fundsPendingWithdrawal(), 0 ether);
  }

  function testFuzzCan_distributeDepositsToRecipients(
    uint64 _threshold,
    uint8 _numDeposits,
    uint256 _ethAmount,
    uint256 _erc20Amount
  ) public {
    _ethAmount = uint256(bound(_ethAmount, 0.01 ether, 34 ether));
    _erc20Amount = uint256(bound(_erc20Amount, 0.01 ether, 34 ether));
    vm.assume(_numDeposits > 0 && _numDeposits < 32);
    vm.assume(_threshold > 0 && _threshold < 2048 * 1e9);
    uint256 principalThresholdWei = uint256(_threshold) * 1e9;

    address _beneficiary = makeAddr("beneficiary");
    address _rewardsRecipient = makeAddr("rewardsRecipient");

    ObolValidatorManager ovm = ovmFactory.createObolValidatorManager(
      address(this),
      _beneficiary,
      _rewardsRecipient,
      _threshold
    );

    uint256 _totalETHAmount = uint256(_numDeposits) * uint256(_ethAmount);
    ovm.deposit{value: _totalETHAmount}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));

    /// test eth
    for (uint256 i = 0; i < _numDeposits; i++) {
      address(ovm).safeTransferETH(_ethAmount);
    }
    ovm.distributeFunds();

    assertEq(address(ovm).balance, 0 ether, "invalid initial balance");
    assertEq(ovm.fundsPendingWithdrawal(), 0 ether, "funds pending withdraw");

    if (principalThresholdWei > _totalETHAmount) {
      // then all of the deposit should be classified as reward
      assertEq(_beneficiary.balance, 0, "should not classify reward as principal");

      assertEq(_rewardsRecipient.balance, _totalETHAmount, "invalid rewards amount");
    }

    if (_ethAmount > principalThresholdWei) {
      // then all of reward classified as principal
      assertEq(_beneficiary.balance, _totalETHAmount, "invalid principal amount");

      assertEq(_rewardsRecipient.balance, 0, "should not classify principal as reward");
    }
  }

  function testFuzzCan_distributePullDepositsToRecipients(
    uint64 _threshold,
    uint8 _numDeposits,
    uint256 _ethAmount,
    uint256 _erc20Amount
  ) public {
    _ethAmount = uint256(bound(_ethAmount, 0.01 ether, 40 ether));
    _erc20Amount = uint256(bound(_erc20Amount, 0.01 ether, 40 ether));
    vm.assume(_numDeposits > 0 && _numDeposits < 32);
    vm.assume(_threshold > 0 && _threshold < 2048 * 1e9);
    uint256 principalThresholdWei = uint256(_threshold) * 1e9;

    address _beneficiary = makeAddr("beneficiary");
    address _rewardsRecipient = makeAddr("rewardsRecipient");

    ObolValidatorManager ovm = ovmFactory.createObolValidatorManager(
      address(this),
      _beneficiary,
      _rewardsRecipient,
      _threshold
    );

    uint256 _totalETHAmount = uint256(_numDeposits) * uint256(_ethAmount);
    ovm.deposit{value: _totalETHAmount}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));

    for (uint256 i = 0; i < _numDeposits; i++) {
      address(ovm).safeTransferETH(_ethAmount);
      ovm.distributeFundsPull();
    }

    assertEq(address(ovm).balance, _totalETHAmount);
    assertEq(ovm.fundsPendingWithdrawal(), _totalETHAmount);

    uint256 principal = ovm.getPullBalance(_beneficiary);
    assertEq(
      ovm.getPullBalance(_beneficiary),
      (_ethAmount >= principalThresholdWei) ? _totalETHAmount : 0,
      "5/invalid recipient balance"
    );

    uint256 reward = ovm.getPullBalance(_rewardsRecipient);
    assertEq(
      ovm.getPullBalance(_rewardsRecipient),
      (_ethAmount >= principalThresholdWei) ? 0 : _totalETHAmount,
      "6/invalid recipient balance"
    );

    ovm.withdrawPullBalance(_beneficiary);
    ovm.withdrawPullBalance(_rewardsRecipient);

    assertEq(address(ovm).balance, 0);
    assertEq(ovm.fundsPendingWithdrawal(), 0);

    assertEq(_beneficiary.balance, principal, "10/invalid principal balance");
    assertEq(_rewardsRecipient.balance, reward, "11/invalid reward balance");
  }

  function test_Transfer_HappyPath() public {
    address newBeneficiary = makeAddr("newBeneficiary");
    address newOwner = makeAddr("newOwner");
    
    assertEq(ovmETH.getBeneficiary(), beneficiary, "initial beneficiary should match");
    assertEq(ovmETH.owner(), address(this), "initial owner should be this contract");
    
    vm.expectEmit(true, true, true, true);
    emit BeneficiaryUpdated(newBeneficiary);
    
    vm.expectEmit(true, true, true, true);
    emit Transferred(newBeneficiary, newOwner);
    
    ovmETH.transfer(newBeneficiary, newOwner);
    
    assertEq(ovmETH.getBeneficiary(), newBeneficiary, "beneficiary should be updated");
    assertEq(ovmETH.owner(), newOwner, "owner should be transferred");
  }

  function testVersion() public view {
    assertEq(ovmETH.version(), "1.0.0");
  }
}
