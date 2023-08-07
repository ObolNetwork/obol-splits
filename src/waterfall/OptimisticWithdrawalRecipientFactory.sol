// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {OptimisticWithdrawalRecipient} from "./OptimisticWithdrawalRecipient.sol";
import {LibClone} from "solady/utils/LibClone.sol";

/// @title OptimisticWithdrawalRecipientFactory
/// @author Obol
/// @notice A factory contract for cheaply deploying OptimisticWithdrawalRecipient.
/// @dev This contract uses token = address(0) to refer to ETH.
contract OptimisticWithdrawalRecipientFactory {
    /// -----------------------------------------------------------------------
    /// errors
    /// -----------------------------------------------------------------------

    /// Invalid token
    error Invalid_Token();

    /// Invalid number of recipients, must be 2
    error Invalid__Recipients();

    /// Thresholds must be positive
    error Invalid__ZeroThreshold();

    /// Invalid threshold at `index`; must be < 2^96
    /// @param threshold threshold of too-large threshold
    error Invalid__ThresholdTooLarge(uint256 threshold);

    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------

    using LibClone for address;

    /// -----------------------------------------------------------------------
    /// events
    /// -----------------------------------------------------------------------

    /// Emitted after a new OptimisticWithdrawalRecipient module is deployed
    /// @param owrModule Address of newly created OptimisticWithdrawalRecipient clone
    /// @param token Address of ERC20 to distribute (0x0 used for ETH)
    /// @param nonOWRecipient Address to recover non-OWR tokens to
    /// @param principalRecipient Address to distribute principal payment to
    /// @param rewardRecipient Address to distribute reward payment to
    /// @param threshold Absolute payment threshold for OWR first recipient
    /// (last recipient has no threshold & receives all residual flows)
    event CreateOWRecipientModule(
        address indexed owrModule,
        address token,
        address nonOWRecipient,
        address principalRecipient,
        address rewardRecipient,
        uint256 threshold
    );

    /// -----------------------------------------------------------------------
    /// storage
    /// -----------------------------------------------------------------------

    uint256 internal constant ADDRESS_BITS = 160;
    uint256 internal constant RECIPIENT_SIZE = 2;

    /// OptimisticWithdrawalRecipient implementation address
    OptimisticWithdrawalRecipient public immutable owrImpl;

    /// -----------------------------------------------------------------------
    /// constructor
    /// -----------------------------------------------------------------------

    constructor() {
        owrImpl = new OptimisticWithdrawalRecipient();
    }

    /// -----------------------------------------------------------------------
    /// functions
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// functions - public & external
    /// -----------------------------------------------------------------------

    /// Create a new OptimisticWithdrawalRecipient clone
    /// @param token Address of ERC20 to distribute (0x0 used for ETH)
    /// @param nonOWRecipient Address to recover non-OWR tokens to
    /// @param principalRecipient Address to distribute principal payments to
    /// @param rewardRecipient Address to distribute reward payments to
    /// @param threshold Absolute payment threshold for principal recipient
    /// (reward recipient has no threshold & receives all residual flows)
    /// @return owr Address of new OptimisticWithdrawalRecipient clone
    function createRecipient(
        address token,
        address nonOWRecipient,
        address principalRecipient,
        address rewardRecipient,
        uint256 threshold
    ) external returns (OptimisticWithdrawalRecipient owr) {
        /// checks

        // ensure token != adress(0)
        if (token == address(0)) {
            revert Invalid_Token();
        }
        // ensure doesn't have address(0)
        if (principalRecipient == address(0) || rewardRecipient == address(0)) {
            revert Invalid__Recipients();
        }
        // ensure threshold isn't zero
        if (threshold == 0) {
            revert Invalid__ZeroThreshold();
        }
        // ensure threshold isn't too large
        if (threshold > type(uint96).max) {
            revert Invalid__ThresholdTooLarge(threshold);
        }

        /// effects

        // copy recipients & threshold into storage
        uint256[] memory tranches = new uint256[](RECIPIENT_SIZE);
        // tranches size == recipients array size
        tranches[0] = (threshold << ADDRESS_BITS) | uint256(uint160(principalRecipient));
        tranches[1] = uint256(uint160(rewardRecipient));

        // would not exceed contract size limits
        bytes memory data = abi.encodePacked(
            token, nonOWRecipient, tranches
        );
        owr = OptimisticWithdrawalRecipient(address(owrImpl).clone(data));
        
        emit CreateOWRecipientModule(
            address(owr), token, nonOWRecipient, principalRecipient, rewardRecipient, threshold
        );
    }
}