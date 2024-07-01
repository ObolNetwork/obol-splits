// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {IObolErc1155Recipient} from "src/interfaces/IObolErc1155Recipient.sol";

contract CreateERC1155RecipientTestData is Script {
    function run(address _erc1155Recipient, address _owr) external {
        IObolErc1155Recipient _recipient = IObolErc1155Recipient(_erc1155Recipient);

        IObolErc1155Recipient.DepositInfo memory depositInfo = IObolErc1155Recipient.DepositInfo({
            pubkey: "",
            withdrawal_credentials: "",
            sig: "",
            root: bytes32(0)
        });

        // Create 3 partitions with the following configuration:
        // - 1 with a max supply of 20 out of which 3 are active
        // - 1 with a max supply of 50 out of which 2 are active
        // - 1 with a max supply of 10, all of them active

        //0
        _recipient.createPartition(20, _owr);

        //1
        _recipient.createPartition(50, _owr);

        //2
        _recipient.createPartition(10, _owr);

        // Recipient should use a mock version of the deposit contract
        // Have 1 active validator in each partition
        for(uint256 i; i < 3; i++) {
            _recipient.mint{value: 0}(i, depositInfo);
        }

        // Activate the rest of the validators in the 3rd partition
        for(uint256 i; i < 9; i++) {
            _recipient.mint{value: 0}(2, depositInfo);
        }
    }
}