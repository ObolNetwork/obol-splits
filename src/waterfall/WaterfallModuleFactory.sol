// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {WaterfallModule} from "./WaterfallModule.sol";
import {LibClone} from "solady/utils/LibClone.sol";

/// @title WaterfallModuleFactory
/// @author Obol
/// @notice A factory contract for cheaply deploying WaterfallModules.
/// @dev This contract uses token = address(0) to refer to ETH.
contract WaterfallModuleFactory {
    /// -----------------------------------------------------------------------
    /// errors
    /// -----------------------------------------------------------------------

    /// Invalid number of recipients, must be 2
    error InvalidWaterfall__Recipients();

    /// Invalid recipient & threshold lengths; recipients must have one more
    /// entry than thresholds
    error InvalidWaterfall__RecipientsAndThresholdsLengthMismatch();

    /// Thresholds must be positive
    error InvalidWaterfall__ZeroThreshold();

    /// Invalid threshold at `index`; must be < 2^96
    /// @param index Index of too-large threshold
    error InvalidWaterfall__ThresholdTooLarge(uint256 index);

    /// Invalid threshold at `index` (thresholds must increase monotonically)
    /// @param index Index of out-of-order threshold
    error InvalidWaterfall__ThresholdsOutOfOrder(uint256 index);

    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------

    using LibClone for address;

    /// -----------------------------------------------------------------------
    /// events
    /// -----------------------------------------------------------------------

    /// Emitted after a new waterfall module is deployed
    /// @param waterfallModule Address of newly created WaterfallModule clone
    /// @param token Address of ERC20 to waterfall (0x0 used for ETH)
    /// @param nonWaterfallRecipient Address to recover non-waterfall tokens to
    /// @param recipients Addresses to waterfall payments to
    /// @param threshold Absolute payment thresholds for waterfall recipients
    /// (last recipient has no threshold & receives all residual flows)
    event CreateWaterfallModule(
        address indexed waterfallModule,
        address token,
        address nonWaterfallRecipient,
        address[] recipients,
        uint256 threshold
    );

    /// -----------------------------------------------------------------------
    /// storage
    /// -----------------------------------------------------------------------

    uint256 internal constant ADDRESS_BITS = 160;
    uint256 internal constant RECIPIENT_SIZE = 2;

    /// WaterfallModule implementation address
    WaterfallModule public immutable wmImpl;

    /// -----------------------------------------------------------------------
    /// constructor
    /// -----------------------------------------------------------------------

    constructor() {
        wmImpl = new WaterfallModule();
    }

    /// -----------------------------------------------------------------------
    /// functions
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// functions - public & external
    /// -----------------------------------------------------------------------

    /// Create a new WaterfallModule clone
    /// @param token Address of ERC20 to waterfall (0x0 used for ETH)
    /// @param nonWaterfallRecipient Address to recover non-waterfall tokens to
    /// @param recipients Addresses to waterfall payments to
    /// @param threshold Absolute payment thresholds for waterfall recipient
    /// (last recipient has no threshold & receives all residual flows)
    /// @return wm Address of new WaterfallModule clone
    function createWaterfallModule(
        address token,
        address nonWaterfallRecipient,
        address[] calldata recipients,
        uint256 threshold
    ) external returns (WaterfallModule wm) {
        /// checks

        // cache lengths for re-use
        uint256 recipientsLength = recipients.length;

        // ensure recipients does not exceed 2 entries
        if (recipientsLength != RECIPIENT_SIZE) {
            revert InvalidWaterfall__Recipients();
        }
        // ensure threshold isn't zero
        if (threshold == 0) {
            revert InvalidWaterfall__ZeroThreshold();
        }
        // ensure threshold isn't too large
        if (threshold > type(uint96).max) {
            revert InvalidWaterfall__ThresholdTooLarge(threshold);
        }

        /// effects

        // copy recipients & threshold into storage
        uint256[] memory tranches = new uint256[](recipientsLength);
        // tranches size == recipients array size
        tranches[0] = (threshold << ADDRESS_BITS) | uint256(uint160(recipients[0]));
        tranches[1] = uint256(uint160(recipients[1]));

        // would exceed contract size limits
        bytes memory data = abi.encodePacked(
            token, nonWaterfallRecipient, tranches
        );
        wm = WaterfallModule(address(wmImpl).clone(data));
        
        emit CreateWaterfallModule(
            address(wm), token, nonWaterfallRecipient, recipients, threshold
        );
    }
}