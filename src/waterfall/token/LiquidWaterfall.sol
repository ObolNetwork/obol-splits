// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import {Ownable} from "solady/auth/Ownable.sol";
import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {LibString} from "solmate/utils/LibString.sol";
import {utils} from "../../lib/Utils.sol";

error DoesNotExist();

/// @notice Deposit contract wrapper which mints an NFT on successful deposit.
/// @author Obol Labs Inc. (https://github.com/ObolNetwork)
contract LiquidWaterfall is ERC1155, Ownable {

    uint256 internal constant TOKEN_ID = 0;

    function initialize(address[] calldata accounts) external {
        // prevent from being initialized multiple times
        require(owner() == address(0), "intialized");
        
        _initializeOwner(msg.sender);

        uint256 numAccs = accounts.length;
        unchecked {
            for (uint256 i; i < numAccs; ++i) {
                _mint({to: accounts[i], id: i, amount: 1, data: ""});
            }
        }
    }

    function uri(uint256 id) public view override returns(string memory) {

    }

    function name() external view returns (string memory) {
        return string.concat("Obol Liquid Waterfall Split ", utils.shortAddressToString(address(this)));
    }
}

// abstract contract LiquidWaterfallCloneImpl is Clone {

//     /// @dev waterfall module
//     IWaterfallFactoryModule public immutable waterfallFactoryModule;

//     /// @dev liquid waterfall factory
//     address internal immutable liquidWaterfallFactory;

//     /// -----------------------------------------------------------------------
//     /// constructor & initializer
//     /// -----------------------------------------------------------------------

//     constructor(address _waterfallModuleFactory) {
//         waterfallFactoryModule = IWaterfallFactoryModule(_waterfallModuleFactory);
//         liquidWaterfallFactory = msg.sender;
//     }

//     function initializer() internal {
//         // waterfallFactoryModule.createWaterfallModule(token, nonWaterfallRecipient, recipients, thresholds);()
//     }

//     /// distributes ETH & ERC20s to NFT holders
//     /// @param token ETH (0x0) or ERC20 token to distribute
//     /// @param accounts Ordered, unique list of NFT holders
//     /// @param distributorAddress Address to receive distributorFee
//     function distributeFunds(address token, address[] calldata accounts, address distributorAddress) external virtual {
        
//     }


//     // function create
// }