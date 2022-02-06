// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "solmate/auth/Auth.sol";

contract WithdrawalRecipient {

    constructor(){

    }

    receive() external payable {}

    function withdraw(address payable recipient) public {
        recipient.transfer(address(this).balance);
    }
}