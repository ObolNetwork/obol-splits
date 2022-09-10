// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "solmate/auth/Auth.sol";
import "ds-test/test.sol";

/// @notice Withdrawal contract that allows only the owner account to withdraw
/// @author Obol Labs Inc. (https://github.com/ObolNetwork)
contract WithdrawalRecipientOwnable is Auth {
    /*///////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    event Withdrawal(address indexed user, address indexed recipient);

    event OwnerChanged(address indexed user, address indexed newOwner);

    /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner, Authority _authority) Auth(_owner, _authority) {}

    /*///////////////////////////////////////////////////////////////
                            WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function withdraw(address payable recipient) public requiresAuth {
        (bool sent,) = recipient.call{value: address(this).balance}("");
        require(sent, "Failed to withdraw balance");

        emit Withdrawal(msg.sender, recipient);
    }

    /*///////////////////////////////////////////////////////////////
                            OWNER CHANGE LOGIC
    //////////////////////////////////////////////////////////////*/

    function changeOwner(address newOwner) public requiresAuth {
        owner = newOwner;

        emit OwnerChanged(msg.sender, newOwner);
    }

    /*///////////////////////////////////////////////////////////////
                            RECEIVE LOGIC
    //////////////////////////////////////////////////////////////*/

    receive() external payable {}

}
