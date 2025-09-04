// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {ObolValidatorManager} from "src/ovm/ObolValidatorManager.sol";
import {ObolValidatorManagerFactory} from "src/ovm/ObolValidatorManagerFactory.sol";
import {MockERC20} from "../utils/mocks/MockERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ObolValidatorManagerReentrancy} from "./ObolValidatorManagerReentrancy.sol";
import {SystemContractMock} from "./mocks/SystemContractMock.sol";
import {DepositContractMock} from "./mocks/DepositContractMock.sol";
import {IENSReverseRegistrar} from "../../interfaces/IENSReverseRegistrar.sol";

contract ObolValidatorManagerTest is Test {
  using SafeTransferLib for address;

  event NewPrincipalRecipient(address indexed newPrincipalRecipient, address indexed oldPrincipalRecipient);
  event NewAmountOfPrincipalStake(uint256 newPrincipalStakeAmount, uint256 oldPrincipalStakeAmount);
  event NewRewardRecipient(address indexed newRewardRecipient, address indexed oldRewardRecipient);
  event DistributeFunds(uint256 principalPayout, uint256 rewardPayout, uint256 pullFlowFlag);
  event RecoverNonOVMFunds(address indexed nonOVMToken, address indexed recipient, uint256 amount);
  event ConsolidationRequested(address indexed requester, bytes indexed source, bytes indexed target);
  event WithdrawalRequested(address indexed requester, bytes indexed pubKey, uint256 amount);

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

  address internal principalRecipient;
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

    principalRecipient = makeAddr("principalRecipient");
    rewardsRecipient = makeAddr("rewardsRecipient");
    principalThreshold = BALANCE_CLASSIFICATION_THRESHOLD_GWEI;

    ovmETH = ovmFactory.createObolValidatorManager(
      address(this),
      principalRecipient,
      rewardsRecipient,
      principalThreshold
    );
    ovmETH_OR = ovmFactory.createObolValidatorManager(
      address(this),
      principalRecipient,
      rewardsRecipient,
      principalThreshold
    );

    ovmETH.deposit{value: INITIAL_DEPOSIT_AMOUNT}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));
    ovmETH_OR.deposit{value: INITIAL_DEPOSIT_AMOUNT}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));
  }

  function testDefaultParameters() public {
    assertEq(ovmETH.principalRecipient(), principalRecipient, "invalid principal recipient");
    assertEq(ovmETH.rewardRecipient(), rewardsRecipient, "invalid rewards recipient");
    assertEq(ovmETH.principalThreshold(), BALANCE_CLASSIFICATION_THRESHOLD_GWEI, "invalid principal threshold");
  }

  function testOwnerInitialization() public {
    assertEq(ovmETH.owner(), address(this));
  }

  function testDeposit() public {
    uint256 depositMockBalance = address(depositMock).balance;
    uint256 amountOfPrincipalStake = ovmETH.amountOfPrincipalStake();
    uint256 depositAmount = 1 ether;
    vm.expectEmit(true, true, true, true);
    emit NewAmountOfPrincipalStake(amountOfPrincipalStake+depositAmount, amountOfPrincipalStake);
    ovmETH.deposit{value: depositAmount}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));
    assertEq(address(depositMock).balance, depositMockBalance + depositAmount);
    assertEq(ovmETH.amountOfPrincipalStake(), amountOfPrincipalStake + depositAmount);
  }

  function testSetPrincipalRecipient() public {
    // initial recipient
    assertEq(ovmETH.principalRecipient(), principalRecipient, "invalid principal recipient");

    address newRecipient = makeAddr("newRecipient");
    vm.expectEmit(true, true, true, true);
    emit NewPrincipalRecipient(newRecipient, principalRecipient);
    ovmETH.setPrincipalRecipient(newRecipient);
    assertEq(ovmETH.principalRecipient(), newRecipient);
  }

  function testSetAmountOfPrincipalStake() public {
    uint256 newAmount = 1 ether;
    uint256 amountOfPrincipalStake = ovmETH.amountOfPrincipalStake();
    vm.expectEmit(true, true, true, true);
    emit NewAmountOfPrincipalStake(newAmount, amountOfPrincipalStake);
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

  function testCannot_setPrincipalRecipient() public {
    // zero address
    vm.expectRevert(ObolValidatorManager.InvalidRequest_Params.selector);
    ovmETH.setPrincipalRecipient(address(0));

    // unauthorized
    address _user = vm.addr(0x2);
    ovmETH.grantRoles(_user, ovmETH.WITHDRAWAL_ROLE()); // unrelated role
    vm.startPrank(_user);
    vm.expectRevert(bytes4(0x82b42900));
    ovmETH.setPrincipalRecipient(makeAddr("noaccess"));
    vm.stopPrank();

    // unauthorized for owner after renounce
    ovmETH.renounceOwnership();
    vm.expectRevert(bytes4(0x82b42900));
    ovmETH.setPrincipalRecipient(makeAddr("noaccess"));
  }

  function testSetRewardRecipient() public {
    // initial recipient
    assertEq(ovmETH.rewardRecipient(), rewardsRecipient, "invalid rewards recipient");

    address newRecipient = makeAddr("newRecipient");
    vm.expectEmit(true, true, true, true);
    emit NewRewardRecipient(newRecipient, rewardsRecipient);
    ovmETH.setRewardRecipient(newRecipient);
    assertEq(ovmETH.rewardRecipient(), newRecipient);
  }

  function testCannot_setRewardRecipient() public {
    // zero address
    vm.expectRevert(ObolValidatorManager.InvalidRequest_Params.selector);
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

  function testCannot_requestConsolidation() public {
    // Unauthorized
    address _user = vm.addr(0x2);
    ovmETH.grantRoles(_user, ovmETH.WITHDRAWAL_ROLE());
    vm.deal(_user, type(uint256).max);
    vm.startPrank(_user);
    vm.expectRevert(bytes4(0x82b42900));
    ovmETH.requestConsolidation{value: 1 ether}(new bytes[](1), new bytes(48));
    vm.stopPrank();

    // Empty source array
    vm.expectRevert(ObolValidatorManager.InvalidRequest_Params.selector);
    bytes[] memory empty = new bytes[](0);
    ovmETH.requestConsolidation{value: 1 ether}(empty, new bytes(48));

    // Not enough fee (1 wei is the minimum fee)
    vm.expectRevert(ObolValidatorManager.InvalidRequest_NotEnoughFee.selector);
    bytes[] memory single = new bytes[](1);
    single[0] = new bytes(48);
    ovmETH.requestConsolidation{value: 0}(single, new bytes(48));

    // Failed get_fee() request
    uint256 realFee = consolidationMock.fakeExponential(0);
    consolidationMock.setFailNextFeeRequest(true);
    vm.expectRevert(ObolValidatorManager.InvalidRequest_SystemGetFee.selector);
    ovmETH.requestConsolidation{value: realFee}(single, new bytes(48));
    consolidationMock.setFailNextFeeRequest(false);

    // Failed add_request() request
    consolidationMock.setFailNextAddRequest(true);
    vm.expectRevert(ObolValidatorManager.InvalidConsolidation_Failed.selector);
    ovmETH.requestConsolidation{value: realFee}(single, new bytes(48));
    consolidationMock.setFailNextAddRequest(false);

    // Maximum number of source pubkeys is 63
    vm.expectRevert(ObolValidatorManager.InvalidRequest_Params.selector);
    bytes[] memory batch64 = new bytes[](64);
    ovmETH.requestConsolidation{value: realFee}(batch64, new bytes(48));
  }

  function testRequestSingleConsolidation() public {
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
    emit ConsolidationRequested(_user, srcPubkey, dstPubkey);
    ovmETH.requestConsolidation{value: 100 wei}(srcPubkeys, dstPubkey);
    vm.stopPrank();

    bytes memory requestData = bytes.concat(srcPubkey, dstPubkey);
    bytes[] memory requestsMade = consolidationMock.getRequests();
    assertEq(requestsMade.length, 1);
    assertEq(requestsMade[0], requestData);
    assertEq(address(consolidationMock).balance, realFee);
    assertEq(_user.balance, 1 ether - realFee);
  }

  function testRequestBatchConsolidation() public {
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
    ovmETH.requestConsolidation{value: expectedTotalFee}(srcPubkeys, dstPubkey);
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

  function testCannot_requestWithdrawal() public {
    // Unauthorized
    address _user = vm.addr(0x2);
    ovmETH.grantRoles(_user, ovmETH.CONSOLIDATION_ROLE());
    vm.deal(_user, type(uint256).max);
    vm.startPrank(_user);
    vm.expectRevert(bytes4(0x82b42900));
    ovmETH.requestWithdrawal{value: 1 ether}(new bytes[](1), new uint64[](1));
    vm.stopPrank();

    uint64[] memory amounts = new uint64[](1);
    bytes[] memory single = new bytes[](1);
    single[0] = new bytes(48);

    // Inequal array lengths
    vm.expectRevert(ObolValidatorManager.InvalidRequest_Params.selector);
    bytes[] memory empty = new bytes[](0);
    ovmETH.requestWithdrawal{value: 1 ether}(empty, amounts);

    // Not enough fee (1 wei is the minimum fee)
    uint256 validAmount = principalThreshold;
    amounts[0] = uint64(validAmount);
    vm.expectRevert(ObolValidatorManager.InvalidRequest_NotEnoughFee.selector);
    ovmETH.requestWithdrawal{value: 0}(single, amounts);

    // Failed get_fee() request
    uint256 realFee = withdrawalMock.fakeExponential(0);
    amounts[0] = uint64(validAmount);
    withdrawalMock.setFailNextFeeRequest(true);
    vm.expectRevert(ObolValidatorManager.InvalidRequest_SystemGetFee.selector);
    ovmETH.requestWithdrawal{value: realFee}(single, amounts);
    withdrawalMock.setFailNextFeeRequest(false);

    // Failed add_request() request
    withdrawalMock.setFailNextAddRequest(true);
    vm.expectRevert(ObolValidatorManager.InvalidWithdrawal_Failed.selector);
    ovmETH.requestWithdrawal{value: realFee}(single, amounts);
    withdrawalMock.setFailNextAddRequest(false);
  }

  function testRequestSingleWithdrawal() public {
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
    emit WithdrawalRequested(_user, pubkey, amount);
    ovmETH.requestWithdrawal{value: 100 wei}(pubkeys, amounts);
    vm.stopPrank();

    bytes memory requestData = abi.encodePacked(pubkey, amount);
    bytes[] memory requestsMade = withdrawalMock.getRequests();
    assertEq(requestsMade.length, 1);
    assertEq(requestsMade[0], requestData);
    assertEq(address(withdrawalMock).balance, realFee);
    assertEq(_user.balance, 1 ether - realFee);
  }

  function testRequestBatchWithdrawal() public {
    uint256 excessFee = 100 wei;
    uint256 expectedTotalFee;
    uint256 numRequests = 10;
    bytes[] memory pubkeys = new bytes[](numRequests);
    uint64[] memory amounts = new uint64[](numRequests);

    for (uint8 i = 0; i < numRequests; i++) {
      expectedTotalFee += withdrawalMock.fakeExponential(i);

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
    ovmETH.requestWithdrawal{value: expectedTotalFee}(pubkeys, amounts);
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
    emit RecoverNonOVMFunds(address(mERC20), principalRecipient, 1 ether);
    ovmETH_OR.recoverFunds(address(mERC20), principalRecipient);
    assertEq(address(ovmETH_OR).balance, 1 ether);
    assertEq(mERC20.balanceOf(address(ovmETH_OR)), 0 ether);
    assertEq(mERC20.balanceOf(principalRecipient), 1 ether);

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
    ovmETH.grantRoles(_user, ovmETH.SET_PRINCIPAL_ROLE()); // unrelated role
    vm.startPrank(_user);

    vm.expectRevert(bytes4(0x82b42900)); // unauthorized
    ovmETH.recoverFunds(address(mERC20), address(1));

    vm.stopPrank();
  }

  function testCan_distributeToNoRecipients() public {
    ovmETH.distributeFunds();
    assertEq(principalRecipient.balance, 0 ether);
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
    assertEq(principalRecipient.balance, 0 ether);
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
    emit NewAmountOfPrincipalStake(0, INITIAL_DEPOSIT_AMOUNT + secondDeposit);
    vm.expectEmit(true, true, true, true);
    emit DistributeFunds(INITIAL_DEPOSIT_AMOUNT + secondDeposit, rewardPayout, 0);
    ovmETH.distributeFunds();
    assertEq(address(ovmETH).balance, 0 ether);
    assertEq(principalRecipient.balance, INITIAL_DEPOSIT_AMOUNT + secondDeposit);
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
    assertEq(principalRecipient.balance, INITIAL_DEPOSIT_AMOUNT);
    assertEq(rewardsRecipient.balance, rewardPayout + secondDeposit);
  }

  function testCan_distributeMultipleDepositsToPrincipalRecipient() public {
    address(ovmETH).safeTransferETH(16 ether);
    ovmETH.distributeFunds();

    address(ovmETH).safeTransferETH(16 ether);
    ovmETH.distributeFunds();

    assertEq(address(ovmETH).balance, 0 ether);
    assertEq(principalRecipient.balance, 32 ether);
    assertEq(rewardsRecipient.balance, 0 ether);
  }

  function testCannot_distributeTooMuch() public {
    vm.deal(address(ovmETH), type(uint128).max);
    ovmETH.distributeFunds();
    vm.deal(address(ovmETH), 1);

    vm.deal(address(ovmETH), type(uint136).max);
    vm.expectRevert(ObolValidatorManager.InvalidDistribution_TooLarge.selector);
    ovmETH.distributeFunds();

    vm.expectRevert(ObolValidatorManager.InvalidDistribution_TooLarge.selector);
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
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardsRecipient.balance, 0 ether);

    assertEq(ovmETH.getPullBalance(principalRecipient), 32 ether);
    assertEq(ovmETH.getPullBalance(rewardsRecipient), 4 ether);

    assertEq(ovmETH.fundsPendingWithdrawal(), 36 ether);

    ovmETH.withdraw(rewardsRecipient);

    assertEq(address(ovmETH).balance, 32 ether);
    assertEq(principalRecipient.balance, 0);
    assertEq(rewardsRecipient.balance, 4 ether);

    assertEq(ovmETH.getPullBalance(principalRecipient), 32 ether);
    assertEq(ovmETH.getPullBalance(rewardsRecipient), 0);

    assertEq(ovmETH.fundsPendingWithdrawal(), 32 ether);

    ovmETH.withdraw(principalRecipient);

    assertEq(address(ovmETH).balance, 0 ether);
    assertEq(principalRecipient.balance, 32 ether);
    assertEq(rewardsRecipient.balance, 4 ether);

    assertEq(ovmETH.getPullBalance(principalRecipient), 0);
    assertEq(ovmETH.getPullBalance(rewardsRecipient), 0);

    assertEq(ovmETH.fundsPendingWithdrawal(), 0 ether);
  }

  function testCan_distributePushAndPull() public {
    // test eth
    address(ovmETH).safeTransferETH(0.5 ether);
    assertEq(address(ovmETH).balance, 0.5 ether, "2/incorrect balance");

    ovmETH.distributeFunds();

    assertEq(address(ovmETH).balance, 0, "3/incorrect balance");
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardsRecipient.balance, 0.5 ether);

    assertEq(ovmETH.getPullBalance(principalRecipient), 0 ether);
    assertEq(ovmETH.getPullBalance(rewardsRecipient), 0 ether);

    assertEq(ovmETH.fundsPendingWithdrawal(), 0 ether);

    address(ovmETH).safeTransferETH(1 ether);
    assertEq(address(ovmETH).balance, 1 ether);

    ovmETH.distributeFundsPull();

    assertEq(address(ovmETH).balance, 1 ether);
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardsRecipient.balance, 0.5 ether);

    assertEq(ovmETH.getPullBalance(principalRecipient), 0 ether);
    assertEq(ovmETH.getPullBalance(rewardsRecipient), 1 ether);

    assertEq(ovmETH.fundsPendingWithdrawal(), 1 ether);

    ovmETH.distributeFunds();

    assertEq(address(ovmETH).balance, 1 ether);
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardsRecipient.balance, 0.5 ether);

    assertEq(ovmETH.getPullBalance(principalRecipient), 0);
    assertEq(ovmETH.getPullBalance(rewardsRecipient), 1 ether);

    assertEq(ovmETH.fundsPendingWithdrawal(), 1 ether);

    ovmETH.distributeFundsPull();

    assertEq(address(ovmETH).balance, 1 ether);
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardsRecipient.balance, 0.5 ether);

    assertEq(ovmETH.getPullBalance(principalRecipient), 0);
    assertEq(ovmETH.getPullBalance(rewardsRecipient), 1 ether);

    assertEq(ovmETH.fundsPendingWithdrawal(), 1 ether);

    address(ovmETH).safeTransferETH(1 ether);
    assertEq(address(ovmETH).balance, 2 ether);

    ovmETH.distributeFunds();

    assertEq(address(ovmETH).balance, 1 ether);
    assertEq(principalRecipient.balance, 0);
    assertEq(rewardsRecipient.balance, 1.5 ether);

    assertEq(ovmETH.getPullBalance(principalRecipient), 0 ether);
    assertEq(ovmETH.getPullBalance(rewardsRecipient), 1 ether);

    assertEq(ovmETH.fundsPendingWithdrawal(), 1 ether);

    ovmETH.withdraw(rewardsRecipient);

    assertEq(address(ovmETH).balance, 0 ether);
    assertEq(principalRecipient.balance, 0);
    assertEq(rewardsRecipient.balance, 2.5 ether);

    assertEq(ovmETH.getPullBalance(principalRecipient), 0 ether);
    assertEq(ovmETH.getPullBalance(rewardsRecipient), 0 ether);

    assertEq(ovmETH.fundsPendingWithdrawal(), 0);

    address(ovmETH).safeTransferETH(1 ether);
    ovmETH.withdraw(rewardsRecipient);

    assertEq(address(ovmETH).balance, 1 ether);
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardsRecipient.balance, 2.5 ether);

    assertEq(ovmETH.getPullBalance(principalRecipient), 0 ether);
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

    address _principalRecipient = makeAddr("principalRecipient");
    address _rewardsRecipient = makeAddr("rewardsRecipient");

    ObolValidatorManager ovm = ovmFactory.createObolValidatorManager(
      address(this),
      _principalRecipient,
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
      assertEq(_principalRecipient.balance, 0, "should not classify reward as principal");

      assertEq(_rewardsRecipient.balance, _totalETHAmount, "invalid rewards amount");
    }

    if (_ethAmount > principalThresholdWei) {
      // then all of reward classified as principal
      assertEq(_principalRecipient.balance, _totalETHAmount, "invalid principal amount");

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

    address _principalRecipient = makeAddr("principalRecipient");
    address _rewardsRecipient = makeAddr("rewardsRecipient");

    ObolValidatorManager ovm = ovmFactory.createObolValidatorManager(
      address(this),
      _principalRecipient,
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

    uint256 principal = ovm.getPullBalance(_principalRecipient);
    assertEq(
      ovm.getPullBalance(_principalRecipient),
      (_ethAmount >= principalThresholdWei) ? _totalETHAmount : 0,
      "5/invalid recipient balance"
    );

    uint256 reward = ovm.getPullBalance(_rewardsRecipient);
    assertEq(
      ovm.getPullBalance(_rewardsRecipient),
      (_ethAmount >= principalThresholdWei) ? 0 : _totalETHAmount,
      "6/invalid recipient balance"
    );

    ovm.withdraw(_principalRecipient);
    ovm.withdraw(_rewardsRecipient);

    assertEq(address(ovm).balance, 0);
    assertEq(ovm.fundsPendingWithdrawal(), 0);

    assertEq(_principalRecipient.balance, principal, "10/invalid principal balance");
    assertEq(_rewardsRecipient.balance, reward, "11/invalid reward balance");
  }
}
