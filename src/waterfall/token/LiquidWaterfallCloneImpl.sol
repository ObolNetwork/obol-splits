// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import {Ownable} from "solady/auth/Ownable.sol";
import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {LibString} from "solmate/utils/LibString.sol";
import {utils} from "../../lib/Utils.sol";
import {Base64} from "solady/utils/Base64.sol";
import {Renderer} from "../../lib/Renderer.sol";


error DoesNotExist();

/// @notice Deposit contract wrapper which mints an NFT on successful deposit.
/// @author Obol Labs Inc. (https://github.com/ObolNetwork)
contract LiquidWaterfallCloneImpl is ERC1155, Ownable {

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

    function uri(uint256) public view override returns(string memory) {
       return string.concat(
            "data:application/json;base64,",
            Base64.encode(
                bytes(
                    string.concat(
                        '{"name": "Obol Liquid Split ',
                        utils.shortAddressToString(address(this)),
                        '", "description": ',
                        '"Each token represents share of this Liquid Waterfall.", ',
                        '"external_url": ',
                        '"https://app.0xsplits.xyz/accounts/',
                        utils.addressToString(address(this)),
                        "/?chainId=",
                        utils.uint2str(block.chainid),
                        '", ',
                        '"image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(Renderer.render(address(this)))),
                        '"}'
                    )
                )
            )
        );
    }

    function name() external view returns (string memory) {
        return string.concat("Obol Liquid Waterfall Split ", utils.shortAddressToString(address(this)));
    }
}
