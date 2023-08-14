// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;
import {LibClone} from "solady/utils/LibClone.sol";
import {ERC20} from 'solmate/tokens/ERC20.sol';
import "./LidoSplit.sol";

contract LidoSplitFactory {

    /// -----------------------------------------------------------------------
    /// errors
    /// -----------------------------------------------------------------------

    /// Invalid wallet
    error Invalid_Wallet();


    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------
    using LibClone for address;

    /// -----------------------------------------------------------------------
    /// events
    /// -----------------------------------------------------------------------

    /// Emitted after lido split
    event CreateLidoSplit(
        address split
    );

    /// -----------------------------------------------------------------------
    /// storage
    /// -----------------------------------------------------------------------

    /// @notice stETH token address
    ERC20 public immutable stETH;

    /// @notice wstETH token address
    ERC20 public immutable wstETH;

    /// @dev lido split fact
    LidoSplit public lidoSplitImpl;

    constructor(ERC20 _stETH, ERC20 _wstETH) {
        stETH = _stETH;
        wstETH = _wstETH;
    }

    function createLidoSplit(address splitWallet) external returns (address lidoSplit) {
        
        if (splitWallet == address(0)) {
            revert Invalid_Wallet();
        }

        bytes memory data = abi.encodePacked(
            stETH,
            wstETH,
            splitWallet
        );
        
        lidoSplit = address(lidoSplitImpl).clone(data);

        emit CreateLidoSplit(lidoSplit);
    }
}