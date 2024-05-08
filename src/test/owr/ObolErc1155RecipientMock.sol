// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {ObolErc1155Recipient} from "src/owr/ObolErc1155Recipient.sol";

contract ObolErc1155RecipientMock is ObolErc1155Recipient {
    constructor(string memory baseUri_, address _owner, address _depositContract) ObolErc1155Recipient(baseUri_, _owner, _depositContract) {
    }

    function setRewards(uint256 id, address owr, uint256 amount) external {
         rewards[owr][id] += amount;
    }
}