// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "solady/auth/Ownable.sol";
import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {LibString} from "solmate/utils/LibString.sol";
import {utils} from "../../lib/Utils.sol";
import {Base64} from "solady/utils/Base64.sol";
import {Renderer} from "../../lib/Renderer.sol";


// @title LW1155CloneImpl
/// @author Obol
/// @notice A minimal liquid waterfall implementation designed to be used as part of a
/// clones-with-immutable-args implementation.
/// Ownership is represented by 1155s (each = 100% of waterfall tranche)

contract LW1155CloneImpl is ERC1155, Ownable {

    /// @dev clone has already been intialised
    error Initialized();

    /// @dev invalida address
    error InvalidAddress();

    /// @dev intialize the clone
    /// @param accounts list of accounts to receive NFTs
    function initialize(address[] calldata accounts) external {
        // prevent from being initialized multiple times
        if (owner() != address(0)) {
            revert Initialized();
        }

        _initializeOwner(msg.sender);

        uint256 numAccs = accounts.length;
        unchecked {
            for (uint256 i; i < numAccs; ++i) {
                if (accounts[i] == address(0)) {
                    revert InvalidAddress();
                }
                _mint({to: accounts[i], id: i, amount: 1, data: ""});
            }
        }
    }

    /// @dev Returns token uri
    function uri(uint256) public view override returns(string memory) {
       return string.concat(
            "data:application/json;base64,",
            Base64.encode(
                bytes(
                    string.concat(
                        '{"name": "Obol Liquid Split ',
                        utils.shortAddressToString(address(this)),
                        '", "description": ',
                        '"Each token represents a tranche of this Liquid Waterfall.", ',
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
