// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "ds-test/test.sol";
import "solmate/tokens/ERC721.sol";

import "../utils/mocks/MockWithdrawalRecipientNFT.sol";
import "../utils/mocks/MockNFT.sol";

contract WithdrawalRecipientNFTTest is DSTest {
  MockNFT nftContract;
  MockWithdrawalRecipientNFT mockWithdrawalRecipientNFT;

  function setUp() public {
    nftContract = new MockNFT();
    mockWithdrawalRecipientNFT = new MockWithdrawalRecipientNFT(nftContract);

    // ensure test contract is the withdrawal owner
    address ownerAddr = mockWithdrawalRecipientNFT.owner();
    assertEq(ownerAddr, address(this));

    // send an NFT to withdrawal contract
    nftContract.mint(address(this), 0);
    nftContract.transferFrom(address(this), address(mockWithdrawalRecipientNFT), 0);
  }

  function testWithdrawAsOwner() public {
    assertEq(nftContract.ownerOf(0), address(mockWithdrawalRecipientNFT));

    mockWithdrawalRecipientNFT.withdraw(payable(address(0xABEE)));

    assertEq(nftContract.ownerOf(0), address(0xABEE));
  }

  function testFailWithdrawAsNonOwner() public {
    mockWithdrawalRecipientNFT.changeOwner(address(0));
    mockWithdrawalRecipientNFT.withdraw(payable(address(0xABEE)));
  }

  function testChangeOwnerAsOwner() public {
    mockWithdrawalRecipientNFT.changeOwner(address(0xABEE));
    assertEq(mockWithdrawalRecipientNFT.owner(), address(0xABEE));
  }

  function testFailChangeOwnerAsNonOwner() public {
    mockWithdrawalRecipientNFT.changeOwner(address(0));
    mockWithdrawalRecipientNFT.changeOwner(address(0xABEE));
  }
}
