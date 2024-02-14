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

    /// @dev Invalid address
    error Invalid_Address();

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

    /// @dev Create a new collector
    /// @dev address(0) is used to represent ETH
    /// @param token collector token address
    /// @param withdrawalAddress withdrawalAddress to receive tokens
    function createCollector(address token, address withdrawalAddress) external  returns (address collector) {
        if (withdrawalAddress == address(0)) revert Invalid_Address();

        collector = address(collectorImpl).clone(
            abi.encodePacked(withdrawalAddress, token)
        );

        emit CreateCollector(token, withdrawalAddress);
    }
}
