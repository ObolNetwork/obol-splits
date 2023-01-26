// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import "ds-test/test.sol";
import "solmate/auth/Auth.sol";
import "solmate/tokens/ERC721.sol";

/// @notice Withdrawal contract that allows sending NFT to withdrawal recipient account
/// @author Obol Labs Inc. (https://github.com/ObolNetwork)
contract WithdrawalRecipientNFT is Auth {
    /*///////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    event Withdrawal(address indexed user, address indexed recipient);

    event OwnerChanged(address indexed user, address indexed newOwner);

    /*///////////////////////////////////////////////////////////////
                                  IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    ERC721 public nftContract;
    uint256 public tokenID;

    /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(ERC721 _nftContract, uint256 _tokenID, address _owner, Authority _authority) Auth(_owner, _authority) {
        nftContract = _nftContract;
        tokenID = _tokenID;
    }

    /*///////////////////////////////////////////////////////////////
                            WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function withdraw(address recipient) public requiresAuth {
        nftContract.transferFrom(address(this), recipient, tokenID);

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
