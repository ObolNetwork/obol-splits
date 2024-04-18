// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {IERC1155Receiver} from "src/interfaces/IERC1155Receiver.sol";
import {ObolErc1155Recipient} from "src/owr/ObolErc1155Recipient.sol";
import {ObolErc1155RecipientMock} from "./ObolErc1155RecipientMock.sol";
import {OptimisticWithdrawalRecipient} from "src/owr/OptimisticWithdrawalRecipient.sol";
import {OptimisticWithdrawalRecipientFactory} from "src/owr/OptimisticWithdrawalRecipientFactory.sol";
import {IENSReverseRegistrar} from "../../interfaces/IENSReverseRegistrar.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract ObolErc1155RecipientTest is Test, IERC1155Receiver {
    using SafeTransferLib for address;

    ObolErc1155RecipientMock recipient;
    string constant BASE_URI = "https://github.com";  
    uint256 internal constant ETH_STAKE = 32 ether;
    address internal constant ETH_ADDRESS = address(0);
    address internal constant ENS_REVERSE_REGISTRAR_GOERLI = 0x084b1c3C81545d370f3634392De611CaaBFf8148;


    function setUp() public {
        recipient = new ObolErc1155RecipientMock(BASE_URI, address(this));
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4){
        return this.onERC1155Received.selector;
    }

    function supportsInterface(bytes4) external pure override returns (bool) {
        return true;
    }

    function testInitialSupply() public {
        assertEq(recipient.totalSupply(), 0);
    }

    function testTransferFrom() public {
        recipient.mint(address(this), 1, ObolErc1155Recipient.OWRInfo({owr: address(0), withdrawalAddress: address(0)}));
        recipient.mint(address(this), 1, ObolErc1155Recipient.OWRInfo({owr: address(0), withdrawalAddress: address(0)}));

        vm.expectRevert();
        recipient.safeTransferFrom(address(this), address(this), 1, 0, "");


        uint256[] memory batchTokens = new uint256[](2);
        batchTokens[0] = 1;
        batchTokens[1] = 2;
        uint256[] memory batchAmounts = new uint256[](2);
        batchAmounts[0] = 0;
        batchAmounts[0] = 1;

        vm.expectRevert();
        recipient.safeBatchTransferFrom(address(this), address(this), batchTokens, batchAmounts, "");
    }

    function testMint() public {
        recipient.mint(address(this), 1, ObolErc1155Recipient.OWRInfo({owr: address(0), withdrawalAddress: address(0)}));
        bool ownerOf1 = recipient.isOwnerOf(1);
        assertEq(ownerOf1, true);

        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        ObolErc1155Recipient.OWRInfo[] memory infos = new ObolErc1155Recipient.OWRInfo[](2);
        infos[0] = ObolErc1155Recipient.OWRInfo({owr: address(0), withdrawalAddress: address(0)});
        infos[1] = ObolErc1155Recipient.OWRInfo({owr: address(0), withdrawalAddress: address(0)});
        recipient.mintBatch(address(this), 2, amounts, infos);
        bool ownerOf2 = recipient.isOwnerOf(2);
        bool ownerOf3 = recipient.isOwnerOf(3);
        assertEq(ownerOf2, true);
        assertEq(ownerOf3, true);
    }

    function testClaim() public {
        address withdrawalAddress = makeAddr("withdrawalAddress");
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
        OptimisticWithdrawalRecipientFactory owrFactory = new OptimisticWithdrawalRecipientFactory("demo.obol.eth", ENS_REVERSE_REGISTRAR_GOERLI, address(this));
    
        OptimisticWithdrawalRecipient owrETH =
            owrFactory.createOWRecipient(ETH_ADDRESS, withdrawalAddress, withdrawalAddress, withdrawalAddress, ETH_STAKE);

        recipient.mint(address(this), 1, ObolErc1155Recipient.OWRInfo({owr: address(owrETH), withdrawalAddress: withdrawalAddress}));

        address(recipient).safeTransferETH(1 ether);
        assertEq(address(recipient).balance, 1 ether);

        recipient.setRewards(1, address(owrETH), 1 ether);
        assertEq(recipient.rewards(address(owrETH), 1), 1 ether);

        recipient.claim(1);
        assertEq(withdrawalAddress.balance, 1 ether);
    }
}