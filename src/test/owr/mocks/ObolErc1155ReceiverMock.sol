// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {IERC1155Receiver} from "src/interfaces/IERC1155Receiver.sol";

contract ObolErc1155ReceiverMock is IERC1155Receiver {
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
}