// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


interface IPullSplit {
    struct Call {
        address to;
        uint256 value;
        bytes data;
    }
    
    struct PullSplitConfiguration {
        address[] recipients;
        uint256[] allocations;
        uint256 totalAllocation;
        uint16 distributionIncentive;
    }
    
    function distribute(
        PullSplitConfiguration calldata _split,
        address _token,
        address _distributor
    ) external;

    function distribute(
        PullSplitConfiguration calldata _split,
        address _token,
        uint256 _distributeAmount,
        bool _performWarehouseTransfer,
        address _distributor
    ) external;

    function execCalls(Call[] calldata _calls)
        external
        payable
        returns (uint256 blockNumber, bytes[] memory returnData);

    function SPLITS_WAREHOUSE() external view returns (address);
}