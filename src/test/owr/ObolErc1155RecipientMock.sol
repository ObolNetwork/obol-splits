// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {ObolErc1155Recipient} from "src/owr/ObolErc1155Recipient.sol";

contract ObolErc1155RecipientMock is ObolErc1155Recipient {
    constructor(string memory baseUri_, address _owner, address _depositContract) ObolErc1155Recipient(baseUri_, _owner, _depositContract) {
    }

    function setRewards(uint256 id, uint256 amount) external {
        claimable[ownerOf[id]] += amount;
    }

    function simulateReceiverMint(uint256 id, uint256 amount) external {
        (bool success,) = address(this).call(abi.encodeWithSelector(this.safeTransferFrom.selector, address(this), ownerOf[id], id, amount, "0x"));
        if (!success) revert TransferFailed();
    }
}