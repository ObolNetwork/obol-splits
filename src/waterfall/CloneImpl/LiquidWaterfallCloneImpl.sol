// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {Clone} from "solady/utils/Clone.sol";
import {IWaterfallFactoryModule} from "../../interfaces/IWaterfallFactoryModule.sol";

abstract contract LiquidWaterfallCloneImpl is Clone {

    /// @dev waterfall module
    IWaterfallFactoryModule public immutable waterfallFactoryModule;

    /// @dev liquid waterfall factory
    address internal immutable liquidWaterfallFactory;

    /// -----------------------------------------------------------------------
    /// constructor & initializer
    /// -----------------------------------------------------------------------

    constructor(address _waterfallModuleFactory) {
        waterfallFactoryModule = IWaterfallFactoryModule(_waterfallModuleFactory);
        liquidWaterfallFactory = msg.sender;
    }

    function initializer() internal {
        // waterfallFactoryModule.createWaterfallModule(token, nonWaterfallRecipient, recipients, thresholds);()
    }

    /// distributes ETH & ERC20s to NFT holders
    /// @param token ETH (0x0) or ERC20 token to distribute
    /// @param accounts Ordered, unique list of NFT holders
    /// @param distributorAddress Address to receive distributorFee
    function distributeFunds(address token, address[] calldata accounts, address distributorAddress) external virtual {
        
    }


    // function create
}