// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import {LibClone} from "solady/utils/LibClone.sol";
import {ObolCollector} from "./ObolCollector.sol";

/// @title ObolCollector
/// @author Obol
/// @notice A factory contract for cheaply deploying ObolCollector.
/// @dev The address returned should be used to as reward address collecting rewards
contract ObolCollectorFactory {
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
    event CreateCollector(address token, address split);


    /// -----------------------------------------------------------------------
    /// storage
    /// -----------------------------------------------------------------------

    /// @dev collector implementation
    ObolCollector public immutable collectorImpl;

    constructor(address _feeRecipient, uint256 _feeShare) {
        collectorImpl = new ObolCollector(_feeRecipient, _feeShare);
    }



    function createCollector(address token, address splitWallet) external  returns (address collector) {
        if (splitWallet == address(0)) revert Invalid_Wallet();

        collector = address(collectorImpl).clone(
            abi.encodePacked(splitWallet, token)
        );

        emit CreateCollector(token, splitWallet);
    }
}
