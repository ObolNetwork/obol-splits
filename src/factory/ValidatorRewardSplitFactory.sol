// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import {IWaterfallFactoryModule} from "../interfaces/IWaterfallFactoryModule.sol";
import {ISplitMain, SplitConfiguration} from "../interfaces/ISplitMain.sol";

/// @dev Creates multiple waterfall contracts and connects
contract ValidatorRewardSplitFactory {
    /// @dev waterfall factory
    IWaterfallFactoryModule public immutable waterfallFactoryModule;

    /// @dev splitMain factory
    ISplitMain public immutable splitMain;

    constructor(address _waterfallFactoryModule, address _splitMain) {
        waterfallFactoryModule = IWaterfallFactoryModule(_waterfallFactoryModule);
        splitMain = ISplitMain(_splitMain);
    }

    /// @dev Create reward split
    /// @param _split Split configuration data
    /// @param _principal address to receive principal
    /// @param _numberOfValidators number of validators being created
    function createRewardSplit(SplitConfiguration calldata _split, address _principal, uint256 _numberOfValidators)
        external
        returns (address[] memory withdrawAddresses, address feeRecipeint)
    {
        feeRecipeint = splitMain.createSplit(
            _split.accounts,
            _split.percentAllocations,
            _split.distributorFee,
            _split.controller
        );

        address[] memory waterfallRecipients = new address[](2);
        waterfallRecipients[0] = _principal;
        waterfallRecipients[1] = feeRecipeint;

        uint256[] memory thresholds = new uint256[](1);
        thresholds[0] = 32 ether;

        withdrawAddresses = new address[](_numberOfValidators);

        for (uint256 i = 0; i < _numberOfValidators;) {
            // create Waterfall contracts
            withdrawAddresses[i] = waterfallFactoryModule.createWaterfallModule(
                address(0x0), address(0x0), waterfallRecipients, thresholds
            );
            unchecked {
                i++;
            }
        }
    }
}
