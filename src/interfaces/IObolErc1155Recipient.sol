// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPullSplit} from "src/interfaces/external/splits/IPullSplit.sol";

interface IObolErc1155Recipient {
    struct DepositInfo {
        bytes pubkey;
        bytes withdrawal_credentials;
        bytes sig;
        bytes32 root;
    }


    function createPartition(uint256 maxSupply, address owr) external;
    function mint(uint256 _partitionId, DepositInfo calldata depositInfo) external payable returns (uint256 mintedId);
    function burn(uint256 _tokenId) external;
    function burnSlashed(uint256 _tokenId) external;
    function distributeRewards(
        uint256 _tokenId,
        address _distributor,
        IPullSplit.PullSplitConfiguration calldata _splitConfig
    ) external;
    function claim(address _user, address _token) external;
}