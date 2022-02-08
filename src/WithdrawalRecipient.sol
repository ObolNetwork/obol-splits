// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "solmate/auth/Auth.sol";
import "ds-test/test.sol";

/// @notice Withdrawal contract that allows only the owner account to withdraw
/// @author Obol Labs Inc. (https://github.com/ObolNetwork)
contract WithdrawalRecipient is Auth, DSTest {
    /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner, Authority _authority) Auth(_owner, _authority) {}

    /*///////////////////////////////////////////////////////////////
                            WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function withdraw(address payable recipient) public requiresAuth {
        (bool sent, bytes memory data) = recipient.call{value: address(this).balance}("");
        require(sent, "Failed to withdraw balance");
    }

    /*///////////////////////////////////////////////////////////////
                            RECEIVE LOGIC
    //////////////////////////////////////////////////////////////*/

    receive() external payable {}

}