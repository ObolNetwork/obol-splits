// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {OptimisticWithdrawalRecipientV2} from "src/owr/OptimisticWithdrawalRecipientV2.sol";
import {OptimisticWithdrawalRecipientV2Factory} from "src/owr/OptimisticWithdrawalRecipientV2Factory.sol";
import {MockERC20} from "../utils/mocks/MockERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {OWRV2Reentrancy} from "./OWRV2Reentrancy.sol";
import {SystemContractMock} from "./mocks/SystemContractMock.sol";
import {DepositContractMock} from "./mocks/DepositContractMock.sol";
import {IENSReverseRegistrar} from "../../interfaces/IENSReverseRegistrar.sol";

contract OptimisticWithdrawalRecipientV2Test is Test {
  using SafeTransferLib for address;

  event DistributeFunds(uint256 principalPayout, uint256 rewardPayout, uint256 pullFlowFlag);
  event RecoverNonOWRecipientFunds(address indexed nonOWRToken, address indexed recipient, uint256 amount);
  event ConsolidationRequested(address indexed requester, bytes indexed source, bytes indexed target);
  event WithdrawalRequested(address indexed requester, bytes indexed pubKey, uint256 amount);

  address public ENS_REVERSE_REGISTRAR = 0x084b1c3C81545d370f3634392De611CaaBFf8148;

  uint64 public constant BALANCE_CLASSIFICATION_THRESHOLD_GWEI = 16 ether / 1 gwei;
  uint256 public constant INITIAL_DEPOSIT_AMOUNT = 32 ether;

  OptimisticWithdrawalRecipientV2Factory public owrFactory;
  OptimisticWithdrawalRecipientV2 owrETH;
  OptimisticWithdrawalRecipientV2 owrETH_OR;

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

    owrFactory = new OptimisticWithdrawalRecipientV2Factory(
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

    owrETH = owrFactory.createOWRecipient(
      address(this),
      principalRecipient,
      rewardsRecipient,
      recoveryAddress,
      principalThreshold
    );
    owrETH_OR = owrFactory.createOWRecipient(
      address(this),
      principalRecipient,
      rewardsRecipient,
      address(0),
      principalThreshold
    );

    owrETH.deposit{value: INITIAL_DEPOSIT_AMOUNT}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));
    owrETH_OR.deposit{value: INITIAL_DEPOSIT_AMOUNT}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));
  }

  function testDefaultParameters() public {
    assertEq(owrETH.recoveryAddress(), recoveryAddress, "invalid recovery address");
    assertEq(owrETH.principalRecipient(), principalRecipient, "invalid principal recipient");
    assertEq(owrETH.rewardRecipient(), rewardsRecipient, "invalid rewards recipient");
    assertEq(owrETH.principalThreshold(), BALANCE_CLASSIFICATION_THRESHOLD_GWEI, "invalid principal threshold");
  }

  function testOwnerInitialization() public {
    assertEq(owrETH.owner(), address(this));
  }

  function testDeposit() public {
    // Initial deposit is done in setUp()
    assertEq(address(owrETH).balance, INITIAL_DEPOSIT_AMOUNT);

    uint256 depositAmount = 1 ether;
    owrETH.deposit{value: depositAmount}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));
    assertEq(address(depositMock).balance, INITIAL_DEPOSIT_AMOUNT + depositAmount);
    assertEq(owrETH.amountOfPrincipalStake(), INITIAL_DEPOSIT_AMOUNT + depositAmount);
  }

  function testCannot_requestConsolidation() public {
    // Unauthorized
    address _user = vm.addr(0x2);
    owrETH.grantRoles(_user, owrETH.WITHDRAWAL_ROLE());
    vm.deal(_user, type(uint256).max);
    vm.startPrank(_user);
    vm.expectRevert(0x82b42900);
    owrETH.requestConsolidation{value: 1 ether}(new bytes[](1), new bytes(48));
    vm.stopPrank();

    // Empty source array
    vm.expectRevert(OptimisticWithdrawalRecipientV2.InvalidRequest_Params.selector);
    bytes[] memory empty = new bytes[](0);
    owrETH.requestConsolidation{value: 1 ether}(empty, new bytes(48));

    // Not enough fee (1 wei is the minimum fee)
    vm.expectRevert(OptimisticWithdrawalRecipientV2.InvalidRequest_NotEnoughFee.selector);
    bytes[] memory single = new bytes[](1);
    single[0] = new bytes(48);
    owrETH.requestConsolidation{value: 0}(single, new bytes(48));

    // Failed get_fee() request
    uint256 realFee = consolidationMock.fakeExponential(0);
    consolidationMock.setFailNextFeeRequest(true);
    vm.expectRevert(OptimisticWithdrawalRecipientV2.InvalidRequest_SystemGetFee.selector);
    owrETH.requestConsolidation{value: realFee}(single, new bytes(48));
    consolidationMock.setFailNextFeeRequest(false);

    // Failed add_request() request
    consolidationMock.setFailNextAddRequest(true);
    vm.expectRevert(OptimisticWithdrawalRecipientV2.InvalidConsolidation_Failed.selector);
    owrETH.requestConsolidation{value: realFee}(single, new bytes(48));
    consolidationMock.setFailNextAddRequest(false);

    // Maximum number of source pubkeys is 63
    vm.expectRevert(OptimisticWithdrawalRecipientV2.InvalidRequest_Params.selector);
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
    vm.expectRevert(0x82b42900);
    owrETH.requestWithdrawal{value: 1 ether}(new bytes[](1), new uint64[](1));
    vm.stopPrank();

    uint64[] memory amounts = new uint64[](1);
    bytes[] memory single = new bytes[](1);
    single[0] = new bytes(48);

    // Inequal array lengths
    vm.expectRevert(OptimisticWithdrawalRecipientV2.InvalidRequest_Params.selector);
    bytes[] memory empty = new bytes[](0);
    owrETH.requestWithdrawal{value: 1 ether}(empty, amounts);

    // Not enough fee (1 wei is the minimum fee)
    uint256 validAmount = principalThreshold;
    amounts[0] = uint64(validAmount);
    vm.expectRevert(OptimisticWithdrawalRecipientV2.InvalidRequest_NotEnoughFee.selector);
    owrETH.requestWithdrawal{value: 0}(single, amounts);

    // Failed get_fee() request
    uint256 realFee = withdrawalMock.fakeExponential(0);
    amounts[0] = uint64(validAmount);
    withdrawalMock.setFailNextFeeRequest(true);
    vm.expectRevert(OptimisticWithdrawalRecipientV2.InvalidRequest_SystemGetFee.selector);
    owrETH.requestWithdrawal{value: realFee}(single, amounts);
    withdrawalMock.setFailNextFeeRequest(false);

    // Failed add_request() request
    withdrawalMock.setFailNextAddRequest(true);
    vm.expectRevert(OptimisticWithdrawalRecipientV2.InvalidWithdrawal_Failed.selector);
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
    vm.expectRevert(OptimisticWithdrawalRecipientV2.InvalidTokenRecovery_InvalidRecipient.selector);
    owrETH.recoverFunds(address(mERC20), address(1));

    vm.expectRevert(OptimisticWithdrawalRecipientV2.InvalidTokenRecovery_InvalidRecipient.selector);
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
    vm.expectRevert(OptimisticWithdrawalRecipientV2.InvalidDistribution_TooLarge.selector);
    owrETH.distributeFunds();

    vm.expectRevert(OptimisticWithdrawalRecipientV2.InvalidDistribution_TooLarge.selector);
    owrETH.distributeFundsPull();
  }

  function testCannot_reenterOWR() public {
    OWRV2Reentrancy wr = new OWRV2Reentrancy();

    owrETH = owrFactory.createOWRecipient(address(this), address(wr), rewardsRecipient, recoveryAddress, 1e9);
    owrETH.deposit{value: 1 ether}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));
    address(owrETH).safeTransferETH(33 ether);

    vm.expectRevert(SafeTransferLib.ETHTransferFailed.selector);
    owrETH.distributeFunds();

    assertEq(address(owrETH).balance, 33 ether);
    assertEq(address(wr).balance, 0 ether);
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
    uint256 _ethAmount,
    uint256 _erc20Amount
  ) public {
    _ethAmount = uint256(bound(_ethAmount, 0.01 ether, 34 ether));
    _erc20Amount = uint256(bound(_erc20Amount, 0.01 ether, 34 ether));
    vm.assume(_numDeposits > 0);
    vm.assume(_threshold > 0 && _threshold < 2048 * 1e9);
    uint256 principalThresholdWei = uint256(_threshold) * 1e9;

    owrETH = owrFactory.createOWRecipient(
      address(this),
      principalRecipient,
      rewardsRecipient,
      recoveryAddress,
      _threshold
    );
    owrETH.deposit{value: INITIAL_DEPOSIT_AMOUNT}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));

    /// test eth
    for (uint256 i = 0; i < _numDeposits; i++) {
      address(owrETH).safeTransferETH(_ethAmount);
    }
    owrETH.distributeFunds();

    uint256 _totalETHAmount = uint256(_numDeposits) * uint256(_ethAmount);

    assertEq(address(owrETH).balance, 0 ether, "invalid balance");
    // assertEq(owrETH.distributedFunds(), _totalETHAmount, "undistributed funds");
    assertEq(owrETH.fundsPendingWithdrawal(), 0 ether, "funds pending withdraw");

    if (principalThresholdWei > _totalETHAmount) {
      // then all of the deposit should be classified as reward
      assertEq(principalRecipient.balance, 0, "should not classify reward as principal");

      assertEq(rewardsRecipient.balance, _totalETHAmount, "invalid amount");
    }

    if (_ethAmount > principalThresholdWei) {
      // then all of reward classified as principal
      // but check if _totalETHAmount > first threshold
      if (_totalETHAmount > principalThresholdWei) {
        // there is reward
        assertEq(principalRecipient.balance, principalThresholdWei, "invalid amount");

        assertEq(
          rewardsRecipient.balance,
          _totalETHAmount - principalThresholdWei,
          "should not classify principal as reward"
        );
      } else {
        // eelse no rewards
        assertEq(principalRecipient.balance, _totalETHAmount, "invalid amount");

        assertEq(rewardsRecipient.balance, 0, "should not classify principal as reward");
      }
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
    vm.assume(_numDeposits > 0);
    vm.assume(_threshold > 0 && _threshold < 2048 * 1e9);
    uint256 principalThresholdWei = uint256(_threshold) * 1e9;

    owrETH = owrFactory.createOWRecipient(
      address(this),
      principalRecipient,
      rewardsRecipient,
      recoveryAddress,
      _threshold
    );
    owrETH.deposit{value: INITIAL_DEPOSIT_AMOUNT}(new bytes(0), new bytes(0), new bytes(0), bytes32(0));

    /// test eth

    for (uint256 i = 0; i < _numDeposits; i++) {
      address(owrETH).safeTransferETH(_ethAmount);
      owrETH.distributeFundsPull();
    }
    uint256 _totalETHAmount = uint256(_numDeposits) * uint256(_ethAmount);

    assertEq(address(owrETH).balance, _totalETHAmount);
    // assertEq(owrETH.distributedFunds(), _totalETHAmount);
    assertEq(owrETH.fundsPendingWithdrawal(), _totalETHAmount);

    uint256 principal = owrETH.getPullBalance(principalRecipient);
    assertEq(
      owrETH.getPullBalance(principalRecipient),
      (_ethAmount >= principalThresholdWei)
        ? principalThresholdWei > _totalETHAmount ? _totalETHAmount : principalThresholdWei
        : 0,
      "5/invalid recipient balance"
    );

    uint256 reward = owrETH.getPullBalance(rewardsRecipient);
    assertEq(
      owrETH.getPullBalance(rewardsRecipient),
      (_ethAmount >= principalThresholdWei)
        ? _totalETHAmount > principalThresholdWei ? (_totalETHAmount - principalThresholdWei) : 0
        : _totalETHAmount,
      "6/invalid recipient balance"
    );

    owrETH.withdraw(principalRecipient);
    owrETH.withdraw(rewardsRecipient);

    assertEq(address(owrETH).balance, 0);
    assertEq(owrETH.fundsPendingWithdrawal(), 0);

    assertEq(principalRecipient.balance, principal, "10/invalid principal balance");
    assertEq(rewardsRecipient.balance, reward, "11/invalid reward balance");
  }
}
