// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC1155} from "solmate/tokens/ERC1155.sol";

contract MockERC1155 is ERC1155 {
    function uri(uint256) public pure override returns (string memory) {
        return "uri";
    }

    function safeMint(address to, uint256 id, uint256 amount, bytes memory data) external {
        _mint(to, id, amount, data);
    }

    function safeBatchMint(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external {
        _batchMint(to, ids, amounts, data);
    }
}