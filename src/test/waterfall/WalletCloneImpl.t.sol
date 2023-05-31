// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "forge-std/Test.sol";
import "../utils/mocks/MockERC1155.sol";
import "../utils/mocks/MockNFT.sol";
import "src/waterfall/wallet/WalletCloneImpl.sol";

contract Base is Test {

    MockERC1155 public mockERC1155;
    MockNFT public mockERC721;

    address public tokenReceiver;

    function setup() public {
        mockERC1155 = new MockERC1155();
        mockERC721 = new MockNFT();
        tokenReceiver = new WalletCloneImpl();
    }
}

contract WalletCloneImpl_ERC1155TokenReceiverTest is Base {
    function testCanReceiveERC1155() external {
        mockERC1155.safeMint(tokenReceiver, 1, 1, "");
    }
}

contract WalletCloneImpl_ERC721TokenReceiverTest is Base {
    function testCanReceiveERC721() external {
        mockERC721.safeMint(tokenReceiver, 1, 1, "");
    }
}

contract WalletCloneImpl_ETHReceiverTest is Base {
    
}