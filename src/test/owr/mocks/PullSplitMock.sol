// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {IPullSplit} from "src/interfaces/external/splits/IPullSplit.sol";


contract PullSplitMock {
    address public SPLITS_WAREHOUSE;

    constructor() {
        SPLITS_WAREHOUSE = address(this);
    }

    function distribute(
        IPullSplit.PullSplitConfiguration calldata,
        address,
        address
    ) external {
        payable(msg.sender).transfer(address(this).balance);
    }

    function execCalls(IPullSplit.Call[] calldata _calls)
        external
        payable
        returns (uint256, bytes[] memory) {
        
        IPullSplit.Call memory firstCall = _calls[0];
        (bool success, ) = firstCall.to.call{value: firstCall.value}(firstCall.data);
        require(success, "failed");
        
        return (1, new bytes[](1));
    }

    receive() external payable {}

    function withdraw(address _to, address) external {
        payable(_to).transfer(address(this).balance);
    }  
}