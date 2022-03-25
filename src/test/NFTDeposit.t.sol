// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "ds-test/test.sol";

import { IDepositContract } from "../NFTDeposit.sol";
import "./utils/mocks/MockNFTDeposit.sol";
import "./utils/mocks/MockDepositContract.sol";

contract NFTDepositTest is DSTest {
    MockNFTDeposit mockNFTDeposit;

    function setUp() public {
        IDepositContract mockDepositContract = new MockDepositContract();
        mockNFTDeposit = new MockNFTDeposit(mockDepositContract);
    }

    function testMintFromDeposit() public {
        bytes memory pubkey = "0x12";
        bytes memory withdrawal_credentials = "0x32";
        bytes memory signature = "0x48";
        bytes32 deposit_data_root = "root";
        uint256 id = mockNFTDeposit.deposit{value: 32e18}(pubkey, withdrawal_credentials, signature, deposit_data_root);

        assertEq(mockNFTDeposit.ownerOf(id), address(this));
    }
}
