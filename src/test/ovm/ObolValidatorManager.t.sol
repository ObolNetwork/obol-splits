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
  event DistributeFunds(uint256 principalPayout, uint256 rewardPayout, uint256 pullFlowFlag);
  event RecoverNonOWRecipientFunds(address indexed nonOWRToken, address indexed recipient, uint256 amount);
  event ConsolidationRequested(address indexed requester, bytes indexed source, bytes indexed target);
  event WithdrawalRequested(address indexed requester, bytes indexed pubKey, uint256 amount);

  address public ENS_REVERSE_REGISTRAR = 0x084b1c3C81545d370f3634392De611CaaBFf8148;

  uint64 public constant BALANCE_CLASSIFICATION_THRESHOLD_GWEI = 16 ether / 1 gwei;
  uint256 public constant INITIAL_DEPOSIT_AMOUNT = 32 ether;

  ObolValidatorManagerFactory public owrFactory;
  ObolValidatorManager owrETH;
  ObolValidatorManager owrETH_OR;

  SystemContractMock consolidationMock;
  SystemContractMock withdrawalMock;
  DepositContractMock depositMock;

  MockERC20 mERC20;

  address internal recoveryAddress;
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

    owrFactory = new ObolValidatorManagerFactory(
      address(consolidationMock),
      address(withdrawalMock),
      address(depositMock),
      "demo.obol.eth",
      ENS_REVERSE_REGISTRAR,
      address(this)
    );

    mERC20 = new MockERC20("demo", "DMT", 18);
    mERC20.mint(type(uint256).max);

    recoveryAddress = makeAddr("recoveryAddress");
    principalRecipient = makeAddr("principalRecipient");
    rewardsRecipient = makeAddr("rewardsRecipient");
    principalThreshold = BALANCE_CLASSIFICATION_THRESHOLD_GWEI;

    owrETH = owrFactory.createObolValidatorManager(
      address(this),
      principalRecipient,
      rewardsRecipient,
      recoveryAddress,
      principalThreshold
    );
    owrETH_OR = owrFactory.createObolValidatorManager(
      address(this),
      principalRecipient,
      rewardsRecipient,
      address(0),
      principalThreshold
    );

    owrETH.deposit{value: INITIAL_DEPOSIT_AMOUNT}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));
    owrETH_OR.deposit{value: INITIAL_DEPOSIT_AMOUNT}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));
  }

  function testDefaultParameters() public view {
    assertEq(owrETH.recoveryAddress(), recoveryAddress, "invalid recovery address");
    assertEq(owrETH.principalRecipient(), principalRecipient, "invalid principal recipient");
    assertEq(owrETH.rewardRecipient(), rewardsRecipient, "invalid rewards recipient");
    assertEq(owrETH.principalThreshold(), BALANCE_CLASSIFICATION_THRESHOLD_GWEI, "invalid principal threshold");
  }

  function testOwnerInitialization() public view {
    assertEq(owrETH.owner(), address(this));
  }

  function testDeposit() public {
    // Initial deposit is done in setUp()
    assertEq(owrETH.amountOfPrincipalStake(), INITIAL_DEPOSIT_AMOUNT);

    uint256 depositAmount = 1 ether;
    owrETH.deposit{value: depositAmount}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));
    assertEq(owrETH.amountOfPrincipalStake(), INITIAL_DEPOSIT_AMOUNT + depositAmount);
  }

  function testSetPrincipalRecipient() public {
    // initial recipient
    assertEq(owrETH.principalRecipient(), principalRecipient, "invalid principal recipient");

    address newRecipient = makeAddr("newRecipient");
    vm.expectEmit(true, true, true, true);
    emit NewPrincipalRecipient(newRecipient, principalRecipient);
    owrETH.setPrincipalRecipient(newRecipient);
    assertEq(owrETH.principalRecipient(), newRecipient);
  }

  function testCannot_setPrincipalRecipient() public {
    // zero address
    vm.expectRevert(ObolValidatorManager.InvalidRequest_Params.selector);
    owrETH.setPrincipalRecipient(address(0));

    // unauthorized
    address _user = vm.addr(0x2);
    owrETH.grantRoles(_user, owrETH.WITHDRAWAL_ROLE()); // unrelated role
    vm.startPrank(_user);
    vm.expectRevert(bytes4(0x82b42900));
    owrETH.setPrincipalRecipient(makeAddr("noaccess"));
    vm.stopPrank();

    // unauthorized for owner after renounce
    owrETH.renounceOwnership();
    vm.expectRevert(bytes4(0x82b42900));
    owrETH.setPrincipalRecipient(makeAddr("noaccess"));
  }

  function testCannot_requestConsolidation() public {
    // Unauthorized
    address _user = vm.addr(0x2);
    owrETH.grantRoles(_user, owrETH.WITHDRAWAL_ROLE());
    vm.deal(_user, type(uint256).max);
    vm.startPrank(_user);
    vm.expectRevert(bytes4(0x82b42900));
    owrETH.requestConsolidation{value: 1 ether}(new bytes[](1), new bytes(48));
    vm.stopPrank();

    // Empty source array
    vm.expectRevert(ObolValidatorManager.InvalidRequest_Params.selector);
    bytes[] memory empty = new bytes[](0);
    owrETH.requestConsolidation{value: 1 ether}(empty, new bytes(48));

    // Not enough fee (1 wei is the minimum fee)
    vm.expectRevert(ObolValidatorManager.InvalidRequest_NotEnoughFee.selector);
    bytes[] memory single = new bytes[](1);
    single[0] = new bytes(48);
    owrETH.requestConsolidation{value: 0}(single, new bytes(48));

    // Failed get_fee() request
    uint256 realFee = consolidationMock.fakeExponential(0);
    consolidationMock.setFailNextFeeRequest(true);
    vm.expectRevert(ObolValidatorManager.InvalidRequest_SystemGetFee.selector);
    owrETH.requestConsolidation{value: realFee}(single, new bytes(48));
    consolidationMock.setFailNextFeeRequest(false);

    // Failed add_request() request
    consolidationMock.setFailNextAddRequest(true);
    vm.expectRevert(ObolValidatorManager.InvalidConsolidation_Failed.selector);
    owrETH.requestConsolidation{value: realFee}(single, new bytes(48));
    consolidationMock.setFailNextAddRequest(false);

    // Maximum number of source pubkeys is 63
    vm.expectRevert(ObolValidatorManager.InvalidRequest_Params.selector);
    bytes[] memory batch64 = new bytes[](64);
    owrETH.requestConsolidation{value: realFee}(batch64, new bytes(48));
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
    owrETH.grantRoles(_user, owrETH.CONSOLIDATION_ROLE());
    uint256 realFee = consolidationMock.fakeExponential(0);

    vm.deal(_user, 1 ether);
    vm.startPrank(_user);
    vm.expectEmit(true, true, true, true);
    emit ConsolidationRequested(_user, srcPubkey, dstPubkey);
    owrETH.requestConsolidation{value: 100 wei}(srcPubkeys, dstPubkey);
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
    owrETH.grantRoles(_user, owrETH.CONSOLIDATION_ROLE());

    vm.deal(_user, expectedTotalFee + excessFee);
    vm.startPrank(_user);
    owrETH.requestConsolidation{value: expectedTotalFee}(srcPubkeys, dstPubkey);
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
    owrETH.grantRoles(_user, owrETH.CONSOLIDATION_ROLE());
    vm.deal(_user, type(uint256).max);
    vm.startPrank(_user);
    vm.expectRevert(bytes4(0x82b42900));
    owrETH.requestWithdrawal{value: 1 ether}(new bytes[](1), new uint64[](1));
    vm.stopPrank();

    uint64[] memory amounts = new uint64[](1);
    bytes[] memory single = new bytes[](1);
    single[0] = new bytes(48);

    // Inequal array lengths
    vm.expectRevert(ObolValidatorManager.InvalidRequest_Params.selector);
    bytes[] memory empty = new bytes[](0);
    owrETH.requestWithdrawal{value: 1 ether}(empty, amounts);

    // Not enough fee (1 wei is the minimum fee)
    uint256 validAmount = principalThreshold;
    amounts[0] = uint64(validAmount);
    vm.expectRevert(ObolValidatorManager.InvalidRequest_NotEnoughFee.selector);
    owrETH.requestWithdrawal{value: 0}(single, amounts);

    // Failed get_fee() request
    uint256 realFee = withdrawalMock.fakeExponential(0);
    amounts[0] = uint64(validAmount);
    withdrawalMock.setFailNextFeeRequest(true);
    vm.expectRevert(ObolValidatorManager.InvalidRequest_SystemGetFee.selector);
    owrETH.requestWithdrawal{value: realFee}(single, amounts);
    withdrawalMock.setFailNextFeeRequest(false);

    // Failed add_request() request
    withdrawalMock.setFailNextAddRequest(true);
    vm.expectRevert(ObolValidatorManager.InvalidWithdrawal_Failed.selector);
    owrETH.requestWithdrawal{value: realFee}(single, amounts);
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
    owrETH.grantRoles(_user, owrETH.WITHDRAWAL_ROLE());
    uint256 realFee = withdrawalMock.fakeExponential(0);

    vm.deal(_user, 1 ether);
    vm.startPrank(_user);
    vm.expectEmit(true, true, true, true);
    emit WithdrawalRequested(_user, pubkey, amount);
    owrETH.requestWithdrawal{value: 100 wei}(pubkeys, amounts);
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
    owrETH.grantRoles(_user, owrETH.WITHDRAWAL_ROLE());

    vm.deal(_user, expectedTotalFee + excessFee);
    vm.startPrank(_user);
    owrETH.requestWithdrawal{value: expectedTotalFee}(pubkeys, amounts);
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
    address(owrETH).safeTransferETH(1 ether);
    assertEq(address(owrETH).balance, 1 ether);
  }

  function testReceiveTransfer() public {
    payable(address(owrETH)).transfer(1 ether);
    assertEq(address(owrETH).balance, 1 ether);
  }

  function testReceiveERC20() public {
    address(mERC20).safeTransfer(address(owrETH), 1e10);
    assertEq(mERC20.balanceOf(address(owrETH)), 1e10);
  }

  function testCan_recoverNonOWRFundsToRecipient() public {
    address(owrETH).safeTransferETH(1 ether);
    address(mERC20).safeTransfer(address(owrETH), 1 ether);
    address(owrETH_OR).safeTransferETH(1 ether);
    address(mERC20).safeTransfer(address(owrETH_OR), 1 ether);

    vm.expectEmit(true, true, true, true);
    emit RecoverNonOWRecipientFunds(address(mERC20), recoveryAddress, 1 ether);
    owrETH.recoverFunds(address(mERC20), recoveryAddress);
    assertEq(address(owrETH).balance, 1 ether);
    assertEq(mERC20.balanceOf(address(owrETH)), 0 ether);
    assertEq(mERC20.balanceOf(recoveryAddress), 1 ether);

    vm.expectEmit(true, true, true, true);
    emit RecoverNonOWRecipientFunds(address(mERC20), principalRecipient, 1 ether);
    owrETH_OR.recoverFunds(address(mERC20), principalRecipient);
    assertEq(address(owrETH_OR).balance, 1 ether);
    assertEq(mERC20.balanceOf(address(owrETH_OR)), 0 ether);
    assertEq(mERC20.balanceOf(principalRecipient), 1 ether);

    address(mERC20).safeTransfer(address(owrETH_OR), 1 ether);

    vm.expectEmit(true, true, true, true);
    emit RecoverNonOWRecipientFunds(address(mERC20), rewardsRecipient, 1 ether);
    owrETH_OR.recoverFunds(address(mERC20), rewardsRecipient);
    assertEq(address(owrETH_OR).balance, 1 ether);
    assertEq(mERC20.balanceOf(address(owrETH_OR)), 0 ether);
    assertEq(mERC20.balanceOf(rewardsRecipient), 1 ether);
  }

  function testCannot_recoverFundsToNonRecipient() public {
    vm.expectRevert(ObolValidatorManager.InvalidTokenRecovery_InvalidRecipient.selector);
    owrETH.recoverFunds(address(mERC20), address(1));

    vm.expectRevert(ObolValidatorManager.InvalidTokenRecovery_InvalidRecipient.selector);
    owrETH_OR.recoverFunds(address(mERC20), address(2));
  }

  function testCan_OWRIsPayable() public {
    owrETH.distributeFunds{value: 2 ether}();

    assertEq(address(owrETH).balance, 0 ether);
    assertEq(principalRecipient.balance, 0);
    assertEq(rewardsRecipient.balance, 2 ether);
  }

  function testCan_distributeToNoRecipients() public {
    owrETH.distributeFunds();
    assertEq(principalRecipient.balance, 0 ether);
  }

  function testCan_emitOnDistributeToNoRecipients() public {
    uint256 principalPayout;
    uint256 rewardPayout;

    vm.expectEmit(true, true, true, true);
    emit DistributeFunds(principalPayout, rewardPayout, 0);
    owrETH.distributeFunds();
  }

  function testCan_distributeToSecondRecipient() public {
    address(owrETH).safeTransferETH(1 ether);

    uint256 rewardPayout = 1 ether;
    uint256 principalPayout;

    vm.expectEmit(true, true, true, true);
    emit DistributeFunds(principalPayout, rewardPayout, 0);
    owrETH.distributeFunds();
    assertEq(address(owrETH).balance, 0 ether);
    assertEq(rewardsRecipient.balance, 1 ether);

    rewardPayout = 0;
    vm.expectEmit(true, true, true, true);
    emit DistributeFunds(principalPayout, rewardPayout, 0);
    owrETH.distributeFunds();
    assertEq(address(owrETH).balance, 0 ether);
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardsRecipient.balance, 1 ether);
  }

  function testCan_distributeMultipleDepositsTorewardsRecipient() public {
    address(owrETH).safeTransferETH(0.5 ether);
    owrETH.distributeFunds();
    assertEq(address(owrETH).balance, 0 ether);
    assertEq(rewardsRecipient.balance, 0.5 ether);

    address(owrETH).safeTransferETH(0.5 ether);
    owrETH.distributeFunds();
    assertEq(address(owrETH).balance, 0 ether);
    assertEq(rewardsRecipient.balance, 1 ether);
  }

  function testCan_distributeToBothRecipients() public {
    // First deposit of 32eth is done in setUp()
    uint256 secondDeposit = 64 ether;
    owrETH.deposit{value: secondDeposit}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));
    uint256 rewardPayout = 4 ether;
    address(owrETH).safeTransferETH(INITIAL_DEPOSIT_AMOUNT + secondDeposit + rewardPayout);

    vm.expectEmit(true, true, true, true);
    emit DistributeFunds(INITIAL_DEPOSIT_AMOUNT + secondDeposit, rewardPayout, 0);
    owrETH.distributeFunds();
    assertEq(address(owrETH).balance, 0 ether);
    assertEq(principalRecipient.balance, INITIAL_DEPOSIT_AMOUNT + secondDeposit);
    assertEq(rewardsRecipient.balance, rewardPayout);
  }

  function testCan_distributeDirectDepositsAsReward() public {
    // First deposit of 32eth is done in setUp()
    uint256 secondDeposit = 64 ether;
    uint256 rewardPayout = 4 ether;
    address(owrETH).safeTransferETH(INITIAL_DEPOSIT_AMOUNT + secondDeposit + rewardPayout);

    vm.expectEmit(true, true, true, true);
    // Second deposit is classified as reward, because we did not call OWR.deposit()
    emit DistributeFunds(INITIAL_DEPOSIT_AMOUNT, secondDeposit + rewardPayout, 0);
    owrETH.distributeFunds();
    assertEq(address(owrETH).balance, 0 ether);
    assertEq(principalRecipient.balance, INITIAL_DEPOSIT_AMOUNT);
    assertEq(rewardsRecipient.balance, rewardPayout + secondDeposit);
  }

  function testCan_distributeMultipleDepositsToPrincipalRecipient() public {
    address(owrETH).safeTransferETH(16 ether);
    owrETH.distributeFunds();

    address(owrETH).safeTransferETH(16 ether);
    owrETH.distributeFunds();

    assertEq(address(owrETH).balance, 0 ether);
    assertEq(principalRecipient.balance, 32 ether);
    assertEq(rewardsRecipient.balance, 0 ether);
  }

  function testCannot_distributeTooMuch() public {
    vm.deal(address(owrETH), type(uint128).max);
    owrETH.distributeFunds();
    vm.deal(address(owrETH), 1);

    vm.deal(address(owrETH), type(uint136).max);
    vm.expectRevert(ObolValidatorManager.InvalidDistribution_TooLarge.selector);
    owrETH.distributeFunds();

    vm.expectRevert(ObolValidatorManager.InvalidDistribution_TooLarge.selector);
    owrETH.distributeFundsPull();
  }

  function testCannot_reenterOWR() public {
    ObolValidatorManagerReentrancy re = new ObolValidatorManagerReentrancy();

    owrETH = owrFactory.createObolValidatorManager(address(this), address(re), rewardsRecipient, recoveryAddress, 1e9);
    owrETH.deposit{value: 1 ether}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));
    address(owrETH).safeTransferETH(33 ether);

    vm.expectRevert(SafeTransferLib.ETHTransferFailed.selector);
    owrETH.distributeFunds();

    assertEq(address(owrETH).balance, 33 ether);
    assertEq(address(re).balance, 0 ether);
    assertEq(address(0).balance, 0 ether);
  }

  function testCan_distributeToPullFlow() public {
    // test eth
    address(owrETH).safeTransferETH(36 ether);
    owrETH.distributeFundsPull();

    assertEq(address(owrETH).balance, 36 ether);
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardsRecipient.balance, 0 ether);

    assertEq(owrETH.getPullBalance(principalRecipient), 32 ether);
    assertEq(owrETH.getPullBalance(rewardsRecipient), 4 ether);

    assertEq(owrETH.fundsPendingWithdrawal(), 36 ether);

    owrETH.withdraw(rewardsRecipient);

    assertEq(address(owrETH).balance, 32 ether);
    assertEq(principalRecipient.balance, 0);
    assertEq(rewardsRecipient.balance, 4 ether);

    assertEq(owrETH.getPullBalance(principalRecipient), 32 ether);
    assertEq(owrETH.getPullBalance(rewardsRecipient), 0);

    assertEq(owrETH.fundsPendingWithdrawal(), 32 ether);

    owrETH.withdraw(principalRecipient);

    assertEq(address(owrETH).balance, 0 ether);
    assertEq(principalRecipient.balance, 32 ether);
    assertEq(rewardsRecipient.balance, 4 ether);

    assertEq(owrETH.getPullBalance(principalRecipient), 0);
    assertEq(owrETH.getPullBalance(rewardsRecipient), 0);

    assertEq(owrETH.fundsPendingWithdrawal(), 0 ether);
  }

  function testCan_distributePushAndPull() public {
    // test eth
    address(owrETH).safeTransferETH(0.5 ether);
    assertEq(address(owrETH).balance, 0.5 ether, "2/incorrect balance");

    owrETH.distributeFunds();

    assertEq(address(owrETH).balance, 0, "3/incorrect balance");
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardsRecipient.balance, 0.5 ether);

    assertEq(owrETH.getPullBalance(principalRecipient), 0 ether);
    assertEq(owrETH.getPullBalance(rewardsRecipient), 0 ether);

    assertEq(owrETH.fundsPendingWithdrawal(), 0 ether);

    address(owrETH).safeTransferETH(1 ether);
    assertEq(address(owrETH).balance, 1 ether);

    owrETH.distributeFundsPull();

    assertEq(address(owrETH).balance, 1 ether);
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardsRecipient.balance, 0.5 ether);

    assertEq(owrETH.getPullBalance(principalRecipient), 0 ether);
    assertEq(owrETH.getPullBalance(rewardsRecipient), 1 ether);

    assertEq(owrETH.fundsPendingWithdrawal(), 1 ether);

    owrETH.distributeFunds();

    assertEq(address(owrETH).balance, 1 ether);
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardsRecipient.balance, 0.5 ether);

    assertEq(owrETH.getPullBalance(principalRecipient), 0);
    assertEq(owrETH.getPullBalance(rewardsRecipient), 1 ether);

    assertEq(owrETH.fundsPendingWithdrawal(), 1 ether);

    owrETH.distributeFundsPull();

    assertEq(address(owrETH).balance, 1 ether);
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardsRecipient.balance, 0.5 ether);

    assertEq(owrETH.getPullBalance(principalRecipient), 0);
    assertEq(owrETH.getPullBalance(rewardsRecipient), 1 ether);

    assertEq(owrETH.fundsPendingWithdrawal(), 1 ether);

    address(owrETH).safeTransferETH(1 ether);
    assertEq(address(owrETH).balance, 2 ether);

    owrETH.distributeFunds();

    assertEq(address(owrETH).balance, 1 ether);
    assertEq(principalRecipient.balance, 0);
    assertEq(rewardsRecipient.balance, 1.5 ether);

    assertEq(owrETH.getPullBalance(principalRecipient), 0 ether);
    assertEq(owrETH.getPullBalance(rewardsRecipient), 1 ether);

    assertEq(owrETH.fundsPendingWithdrawal(), 1 ether);

    owrETH.withdraw(rewardsRecipient);

    assertEq(address(owrETH).balance, 0 ether);
    assertEq(principalRecipient.balance, 0);
    assertEq(rewardsRecipient.balance, 2.5 ether);

    assertEq(owrETH.getPullBalance(principalRecipient), 0 ether);
    assertEq(owrETH.getPullBalance(rewardsRecipient), 0 ether);

    assertEq(owrETH.fundsPendingWithdrawal(), 0);

    address(owrETH).safeTransferETH(1 ether);
    owrETH.withdraw(rewardsRecipient);

    assertEq(address(owrETH).balance, 1 ether);
    assertEq(principalRecipient.balance, 0 ether);
    assertEq(rewardsRecipient.balance, 2.5 ether);

    assertEq(owrETH.getPullBalance(principalRecipient), 0 ether);
    assertEq(owrETH.getPullBalance(rewardsRecipient), 0 ether);

    assertEq(owrETH.fundsPendingWithdrawal(), 0 ether);
  }

  function testFuzzCan_distributeDepositsToRecipients(
    uint64 _threshold,
    uint8 _numDeposits,
    uint256 _ethAmount
  ) public {
    _ethAmount = uint256(bound(_ethAmount, 1 ether, 30 ether));
    vm.assume(_numDeposits > 0);
    vm.assume(_threshold > 0 && _threshold < 2048);
    uint256 principalThresholdWei = uint256(_threshold) * 1 ether;

    address _rewardsRecipient = makeAddr("rewardsRecipient");
    address _principalRecipient = makeAddr("principalRecipient");

    ObolValidatorManager owr = owrFactory.createObolValidatorManager(
      address(this),
      _principalRecipient,
      _rewardsRecipient,
      recoveryAddress,
      _threshold * 1 gwei
    );

    uint256 _totalETHAmount = uint256(_numDeposits) * _ethAmount;
    owr.deposit{value: _totalETHAmount}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));

    for (uint256 i = 0; i < _numDeposits; i++) {
      address(owr).safeTransferETH(_ethAmount);
    }
    owr.distributeFunds();

    assertEq(address(owr).balance, 0 ether, "invalid balance");
    assertEq(owr.fundsPendingWithdrawal(), 0 ether, "funds pending withdraw");

    if (principalThresholdWei > _totalETHAmount) {
      // then all of the deposit should be classified as reward
      assertEq(_principalRecipient.balance, 0, "should not classify reward as principal");
      assertEq(_rewardsRecipient.balance, _totalETHAmount, "invalid amount");
    }

    if (_ethAmount > principalThresholdWei) {
      // then all of reward classified as principal
      // but check if _totalETHAmount > first threshold
      if (_totalETHAmount > principalThresholdWei) {
        // there is reward
        assertEq(_principalRecipient.balance, _totalETHAmount, "invalid amount");
        assertEq(_rewardsRecipient.balance, 0, "should not classify principal as reward");
      } else {
        // else no rewards
        assertEq(_principalRecipient.balance, _totalETHAmount, "invalid amount");
        assertEq(_rewardsRecipient.balance, 0, "should not classify principal as reward");
      }
    }
  }

  function testFuzzCan_distributePullDepositsToRecipients(
    uint64 _threshold,
    uint8 _numDeposits,
    uint256 _ethAmount
  ) public {
    _ethAmount = uint256(bound(_ethAmount, 1 ether, 30 ether));
    vm.assume(_numDeposits > 0);
    vm.assume(_threshold > 0 && _threshold < 2048);
    uint256 principalThresholdWei = uint256(_threshold) * 1 ether;

    address _rewardsRecipient = makeAddr("rewardsRecipient");
    address _principalRecipient = makeAddr("principalRecipient");

    ObolValidatorManager owr = owrFactory.createObolValidatorManager(
      address(this),
      _principalRecipient,
      _rewardsRecipient,
      recoveryAddress,
      _threshold * 1 gwei
    );

    uint256 _totalETHAmount = uint256(_numDeposits) * _ethAmount;
    owr.deposit{value: _totalETHAmount}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));

    for (uint256 i = 0; i < _numDeposits; i++) {
      address(owr).safeTransferETH(_ethAmount);
      owr.distributeFundsPull();
    }

    assertEq(address(owr).balance, _totalETHAmount);
    assertEq(owr.fundsPendingWithdrawal(), _totalETHAmount);

    uint256 principal = owr.getPullBalance(principalRecipient);
    assertEq(
      owr.getPullBalance(principalRecipient),
      (_ethAmount >= principalThresholdWei) ? _totalETHAmount : 0,
      "5/invalid recipient balance"
    );

    uint256 reward = owr.getPullBalance(rewardsRecipient);
    assertEq(
      owr.getPullBalance(rewardsRecipient),
      (_ethAmount >= principalThresholdWei) ? 0 : _totalETHAmount,
      "6/invalid recipient balance"
    );

    owr.withdraw(principalRecipient);
    owr.withdraw(rewardsRecipient);

    assertEq(address(owr).balance, 0);
    assertEq(owr.fundsPendingWithdrawal(), 0);

    assertEq(principalRecipient.balance, principal, "10/invalid principal balance");
    assertEq(rewardsRecipient.balance, reward, "11/invalid reward balance");
  }
}
