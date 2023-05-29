// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "solmate/tokens/ERC721.sol";

error DoesNotExist();

contract MockNFT is ERC721("NFT", "NFT") {
  function tokenURI(uint256 id) public view override returns (string memory) {
    if (ownerOf[id] == address(0)) revert DoesNotExist();

    return string(abi.encodePacked("NFT", id));
  }

  function mint(address to, uint256 tokenID) external {
    _mint(to, tokenID);
  }
}
