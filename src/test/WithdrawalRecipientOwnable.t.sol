// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "ds-test/test.sol";

import "./utils/mocks/MockWithdrawalRecipient.sol";

contract WithdrawalRecipientOwnableTest is DSTest {
    MockWithdrawalRecipient mockWithdrawalRecipient;

    function setUp() public {
        mockWithdrawalRecipient = new MockWithdrawalRecipient();

        // ensure test contract is the withdrawal owner
        address ownerAddr = mockWithdrawalRecipient.owner();
        assertEq(ownerAddr, address(this));

        // send some ether to withdrawal contract
        (bool sent,) = address(mockWithdrawalRecipient).call{value: address(this).balance}("");
        require(sent, "Failed to send eth");
    }

    function testWithdrawAsOwner() public {
        uint initialBalance = address(mockWithdrawalRecipient).balance;

        mockWithdrawalRecipient.withdraw(payable(address(0xABEE)));

        assertEq(address(mockWithdrawalRecipient).balance, 0);
        assertEq(address(0xABEE).balance, initialBalance);
    }

    function testFailWithdrawAsNonOwner() public {
        mockWithdrawalRecipient.setOwner(address(0));
        mockWithdrawalRecipient.withdraw(payable(address(0xABEE)));
    }

    function testChangeOwnerAsOwner() public {
        mockWithdrawalRecipient.setOwner(address(0xABEE));
        assertEq(mockWithdrawalRecipient.owner(), address(0xABEE));
    }

    function testFailChangeOwnerAsNonOwner() public {
        mockWithdrawalRecipient.setOwner(address(0));
        mockWithdrawalRecipient.setOwner(address(0xABEE));
    }

}
