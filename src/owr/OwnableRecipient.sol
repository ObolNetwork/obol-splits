// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";


/// @title OwnableRecipient
/// @author Obol
/// @notice OWR recipient
/// @dev This contract uses token = address(0) to refer to ETH.
contract OwnableRecipient is Ownable {
    using SafeTransferLib for address;

    /// -----------------------------------------------------------------------
    /// errors
    /// -----------------------------------------------------------------------

    /// @dev thrown if ETH claim fails
    error ClaimFailed(uint256 amount);

    constructor() {
        _initializeOwner(msg.sender);
    }
    
    receive() payable external {}

    /// @notice Claims tokens from contract
    /// @dev uses token = address(0) to refer to ETH.
    /// @param withdrawalRecipient Account to receive tokens
    function claim(address token, address withdrawalRecipient) onlyOwner external {
        if (token == address(0)) {
            uint256 amount = address(this).balance;
            (bool sent,) = withdrawalRecipient.call{value: amount}("");
            if (!sent) revert ClaimFailed(amount);
        } else {
            uint256 balance = ERC20(token).balanceOf(address(this));
            token.safeTransfer(withdrawalRecipient, balance);
        }
    }
}