// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ObolErc1155Recipient} from "src/owr/ObolErc1155Recipient.sol";
import {ObolErc1155RecipientMock} from "./ObolErc1155RecipientMock.sol";
import {OptimisticPullWithdrawalRecipient} from "src/owr/OptimisticPullWithdrawalRecipient.sol";
import {OptimisticPullWithdrawalRecipientFactory} from "src/owr/OptimisticPullWithdrawalRecipientFactory.sol";

import {IERC1155Receiver} from "src/interfaces/IERC1155Receiver.sol";
import {ISplitMain} from "src/interfaces/external/splits/ISplitMain.sol";
import {IPullSplit} from "src/interfaces/external/splits/IPullSplit.sol";
import {IENSReverseRegistrar} from "../../interfaces/external/IENSReverseRegistrar.sol";
import {IObolErc1155Recipient} from "src/interfaces/IObolErc1155Recipient.sol";


import {PullSplitMock} from "./mocks/PullSplitMock.sol";
import {DepositContractMock} from "./mocks/DepositContractMock.sol";
import {ObolErc1155ReceiverMock} from "./mocks/ObolErc1155ReceiverMock.sol";

contract ObolErc1155RecipientTest is Test, IERC1155Receiver {
  using SafeTransferLib for address;

  ObolErc1155RecipientMock recipient;
  DepositContractMock depositContract;
  PullSplitMock pullSplitMock;
  string constant BASE_URI = "https://github.com";
  uint256 internal constant ETH_STAKE = 32 ether;
  address internal constant ETH_ADDRESS = address(0);
  address internal constant ENS_REVERSE_REGISTRAR_GOERLI = 0x084b1c3C81545d370f3634392De611CaaBFf8148;

  receive() external payable {}

  function setUp() public {
    depositContract = new DepositContractMock();
    recipient = new ObolErc1155RecipientMock(BASE_URI, address(this), address(depositContract));
    pullSplitMock = new PullSplitMock();
  }

  function onERC1155Received(address, address, uint256, uint256, bytes calldata)
    external
    pure
    override
    returns (bytes4)
  {
    return this.onERC1155Received.selector;
  }

  function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
    external
    pure
    override
    returns (bytes4)
  {
    return this.onERC1155Received.selector;
  }

  function supportsInterface(bytes4) external pure override returns (bool) {
    return true;
  }

  function testInitialSupply_owrErc1155() public {
    assertEq(recipient.totalSupplyAll(), 0);
  }

  function testCreatePartition_owrErc1155() public {
    address owrAddress = makeAddr("owrAddress");
    recipient.createPartition(10, owrAddress);
    (uint256 maxSupply, address owr, address operator) = recipient.partitions(0);
    assertEq(maxSupply, 10);
    assertEq(owr, owrAddress);
    assertEq(operator, address(this));
    assertEq(recipient.getPartitionTokensLength(0), 0);
  }

  function testMint_owrErc1155() public {
    address owrAddress = makeAddr("owrAddress");
    recipient.createPartition(10, owrAddress);
    recipient.mint{value: 32 ether}(0, IObolErc1155Recipient.DepositInfo({pubkey: "0x", withdrawal_credentials: "0x", sig: "0x", root: bytes32(0)}));
    recipient.mint{value: 32 ether}(0, IObolErc1155Recipient.DepositInfo({pubkey: "0x", withdrawal_credentials: "0x", sig: "0x", root: bytes32(0)}));

    uint256 firstToken = recipient.partitionTokens(0, 0);
    assertEq(recipient.ownerOf(firstToken), address(this));
    assertEq(recipient.ownerOf(1), address(this));
    assertEq(recipient.getPartitionTokensLength(0), 2);
  }

  
  function testRewards_owrErc1155() public {
    vm.mockCall(
      ENS_REVERSE_REGISTRAR_GOERLI,
      abi.encodeWithSelector(IENSReverseRegistrar.setName.selector),
      bytes.concat(bytes32(0))
    );
    vm.mockCall(
      ENS_REVERSE_REGISTRAR_GOERLI,
      abi.encodeWithSelector(IENSReverseRegistrar.claim.selector),
      bytes.concat(bytes32(0))
    );
    OptimisticPullWithdrawalRecipientFactory owrFactory =
      new OptimisticPullWithdrawalRecipientFactory("demo.obol.eth", ENS_REVERSE_REGISTRAR_GOERLI, address(this));

    OptimisticPullWithdrawalRecipient owrETH =
      owrFactory.createOWRecipient(ETH_ADDRESS, address(pullSplitMock), address(this), address(pullSplitMock), ETH_STAKE);

    recipient.createPartition(10, address(owrETH));
    recipient.mint{value: 32 ether}(0, IObolErc1155Recipient.DepositInfo({pubkey: "0x", withdrawal_credentials: "0x", sig: "0x", root: bytes32(0)}));

    address(owrETH).safeTransferETH(1 ether);
    assertEq(address(owrETH).balance, 1 ether);

    recipient.distributeRewards(0, address(this), IPullSplit.PullSplitConfiguration({
      recipients: new address[](0),
      allocations: new uint256[](0),
      totalAllocation: 0,
      distributionIncentive: 0
    }));

    uint256 claimable = recipient.claimable(address(this), ETH_ADDRESS);
    assertEq(claimable, 1 ether);
  }

  function testBurn_owrErc1155() public {
    vm.mockCall(
      ENS_REVERSE_REGISTRAR_GOERLI,
      abi.encodeWithSelector(IENSReverseRegistrar.setName.selector),
      bytes.concat(bytes32(0))
    );
    vm.mockCall(
      ENS_REVERSE_REGISTRAR_GOERLI,
      abi.encodeWithSelector(IENSReverseRegistrar.claim.selector),
      bytes.concat(bytes32(0))
    );
    OptimisticPullWithdrawalRecipientFactory owrFactory =
      new OptimisticPullWithdrawalRecipientFactory("demo.obol.eth", ENS_REVERSE_REGISTRAR_GOERLI, address(this));

    OptimisticPullWithdrawalRecipient owrETH =
      owrFactory.createOWRecipient(ETH_ADDRESS, address(pullSplitMock), address(recipient), address(pullSplitMock), ETH_STAKE);

    recipient.createPartition(2, address(owrETH));
    recipient.mint{value: 32 ether}(0, IObolErc1155Recipient.DepositInfo({pubkey: "0x", withdrawal_credentials: "0x", sig: "0x", root: bytes32(0)}));

    address(owrETH).safeTransferETH(32 ether);
    assertEq(address(owrETH).balance, 32 ether);

    uint256 balanceBefore = address(this).balance;
    recipient.burn(0);
    uint256 balanceAfter = address(this).balance;
    assertEq(balanceBefore + 32 ether, balanceAfter);
  }
}
