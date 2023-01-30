// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import {IWaterfallFactoryModule} from "../interfaces/IWaterfallFactoryModule.sol";
import {ISplitMain, SplitConfiguration} from "../interfaces/ISplitMain.sol";

/// @dev Creates multiple waterfall contracts and connects it to a splitter contract
contract ValidatorRewardSplitFactory {

    /// @dev amount of ETH required to run a validator
    uint256 constant internal ETH_STAKE = 32 ether;

    /// @dev waterfall eth token representation
    address constant internal WATERFALL_ETH_TOKEN_ADDRESS = address(0x0);

    /// @dev non waterfall receipient
    address constant internal NON_WATERFALL_TOKEN_RECIPIENT = address(0x0);

    /// @dev waterfall factory
    IWaterfallFactoryModule public immutable waterfallFactoryModule;

    /// @dev splitMain factory
    ISplitMain public immutable splitMain;

    constructor(address _waterfallFactoryModule, address _splitMain) {
        waterfallFactoryModule = IWaterfallFactoryModule(_waterfallFactoryModule);
        splitMain = ISplitMain(_splitMain);
    }

    /// @dev Create reward split for ETH rewards
    /// @param _split Split configuration data
    /// @param _principal address to receive principal
    /// @param _numberOfValidators number of validators being created
    function createETHRewardSplit(SplitConfiguration calldata _split, address _principal, uint256 _numberOfValidators)
        external
        returns (address[] memory withdrawAddresses, address splitRecipient)
    {
        splitRecipient = splitMain.createSplit(
            _split.accounts,
            _split.percentAllocations,
            _split.distributorFee,
            _split.controller
        );

        address[] memory waterfallRecipients = new address[](2);
        waterfallRecipients[0] = _principal;
        waterfallRecipients[1] = splitRecipient;

        uint256[] memory thresholds = new uint256[](1);
        thresholds[0] = ETH_STAKE;

        withdrawAddresses = new address[](_numberOfValidators);

        for (uint256 i = 0; i < _numberOfValidators;) {
            withdrawAddresses[i] = waterfallFactoryModule.createWaterfallModule(
                WATERFALL_ETH_TOKEN_ADDRESS, NON_WATERFALL_TOKEN_RECIPIENT, waterfallRecipients, thresholds
            );
            unchecked {
                i++;
            }
        }
    }
}
