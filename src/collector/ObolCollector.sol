// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Clone} from "solady/utils/Clone.sol";


contract ObolCollector is Clone {
    
    error Invalid_Address();
    
    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address;
    
    address internal constant ETH_ADDRESS = address(0);
    uint256 internal constant PERCENTAGE_SCALE = 1e5;

    /// @notice fee share
    uint256 public immutable feeShare;

    /// @notice fee address
    address public immutable feeRecipient;

    // splitWallet (adress, 20 bytes)
    // 0; first item
    uint256 internal constant SPLIT_WALLET_ADDRESS_OFFSET = 0;
    // 20 = splitwallet_offset (0) + splitwallet_size (address, 20 bytes)
    uint256 internal constant TOKEN_ADDRESS_OFFSET = 20;

    constructor(address _feeRecipient, uint256 _feeShare) {
        feeShare = _feeShare;
        feeRecipient = _feeRecipient;
    }
    
    function distribute() external {
        uint256 amount = 0;
        address tokenAddress = token();

        if (tokenAddress == ETH_ADDRESS) {
            amount = address(this).balance;
        } else {
            amount = ERC20(tokenAddress).balanceOf(address(this));
        }

        if (feeShare > 0) {
            uint256 fee = (amount * feeShare) / PERCENTAGE_SCALE;
            _transfer(tokenAddress, feeRecipient, fee);
            _transfer(tokenAddress, splitWallet(), amount -= fee);
        } else {
             _transfer(tokenAddress, splitWallet(), amount);
        }
    }

    /// Address of split wallet to send funds to to
    /// @dev equivalent to address public immutable splitWallet
    function splitWallet() public pure returns (address) {
        return _getArgAddress(SPLIT_WALLET_ADDRESS_OFFSET);
    }

    function token() public pure returns (address) {
        return _getArgAddress(TOKEN_ADDRESS_OFFSET);
    }

    function rescueFunds(address tokenAddress) external returns (uint256 balance) {
        // prevent bypass
        if (tokenAddress == token()) revert Invalid_Address();

        if (tokenAddress == ETH_ADDRESS) {
        balance = address(this).balance;
        if (balance > 0) splitWallet().safeTransferETH(balance);
        } else {
        balance = ERC20(tokenAddress).balanceOf(address(this));
        if (balance > 0) ERC20(tokenAddress).safeTransfer(splitWallet(), balance);
        }
    }

    function _transfer(
        address tokenAddress, 
        address receiver,
        uint256 amount
    ) internal {
        if (tokenAddress == ETH_ADDRESS) {
            receiver.safeTransferETH(amount);
        } else {
            ERC20(tokenAddress).safeTransfer(receiver, amount);
        }
    }
}
