// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

contract LiquidWaterfallFactory {

    /// @dev waterfall module factory
    address public waterfallModuleFactory;


    constructor(address _waterfallMouleFactory) {
        waterfallModuleFactory = _waterfallMouleFactory;
    }

    /// Create a new WaterfallModule clone
    /// @param _token Address of ERC20 to waterfall (0x0 used for ETH)
    /// @param _nonWaterfallRecipient Address to recover non-waterfall tokens to
    /// @param _recipients Addresses to waterfall payments to
    /// @param _thresholds Absolute payment thresholds for waterfall recipients
    /// (last recipient has no threshold & receives all residual flows)
    /// @return liquidWaterfall Address of new WaterfallModule clone
    function createLiquidWaterfall(
        address _token,
        address _nonWaterfallRecipient,
        address[] calldata _recipients,
        uint256[] calldata _thresholds
    ) external returns (address liquidWaterfall) {
        // deploy nft
        // deploy wallet
        
        // mint nft to wallet

        // deploy waterfall

    }

    // function 

    function _mintNft() internal {

    }

    function _createWallet(address ) internal {

    }
}