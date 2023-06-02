// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "solady/auth/Ownable.sol";
import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {LibString} from "solmate/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";
import {ERC20} from 'solmate/tokens/ERC20.sol';
import {TokenUtils} from "splits-utils/TokenUtils.sol";
import {utils} from "../../lib/Utils.sol";
import {Renderer} from "../../lib/Renderer.sol";
import {ISplitMain, SplitConfiguration} from "../../interfaces/ISplitMain.sol";
import {IWaterfallModule} from "../../interfaces/IWaterfallModule.sol";

// @title LW1155
/// @author Obol
/// @notice A minimal liquid waterfall implementation designed to be used as part of a
/// clones-with-immutable-args implementation.
/// Ownership is represented by 1155s (each = 100% of waterfall tranche)
contract LW1155 is ERC1155, Ownable {

    /// @dev invalid address
    error InvalidAddress();

    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------

    using TokenUtils for address;

    /// -----------------------------------------------------------------------
    /// events
    /// -----------------------------------------------------------------------
    // emitted in clone bytecode
    event ReceiveETH(uint256 amount);


    /// -----------------------------------------------------------------------
    /// structs
    /// -----------------------------------------------------------------------
    struct Call {
        address to;
        uint256 value;
        bytes data;
    }

    struct Claim {
        ISplitMain split;
        IWaterfallModule waterfall;
        SplitConfiguration configuration; 
    }

    /// -----------------------------------------------------------------------
    /// storage
    /// -----------------------------------------------------------------------
    /// @dev splitMain factory
    ISplitMain public immutable splitMain;
    
    /// -----------------------------------------------------------------------
    /// storage - mutables
    /// -----------------------------------------------------------------------

    /// @dev nft claim information
    mapping (uint256 => Claim) public claimData;

    constructor(ISplitMain _splitMain) {
        splitMain = _splitMain;
        _initializeOwner(msg.sender);
    }

    /// @dev Mint NFT
    /// @param _recipient address to receive minted NFT
    /// @param _configuration split configuration
    function mint(address _recipient, address _split, address _waterfall, SplitConfiguration calldata _configuration) external onlyOwner {
        // waterfall is unique per validator
        uint256 id = uint256(keccak256(abi.encodePacked(_recipient, _waterfall)));
        Claim memory claiminfo = Claim(
            ISplitMain(_split), IWaterfallModule(_waterfall), _configuration
        );
        claimData[id] = claiminfo;
        _mint({to: _recipient, id: id, amount: 1, data: ""});
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
    
    /// @dev send tokens and ETH to receiver
    /// @notice Ensures the receiver is the right address to receive the tokens
    /// @param tokenIds address of tokens, address(0) represents ETH
    /// @param receiver address holding the NFT
    function claim(uint256[] calldata tokenIds, address receiver) external {
        uint256 size = tokenIds.length;

        for (uint256 i = 0; i < size;) {
            uint256 tokenId = tokenIds[i];
            require(balanceOf[receiver][tokenId] >= 1, "invalid_owner");

            // fetch claim information
            Claim memory tokenClaim = claimData[tokenId];

            // claim from waterfall
            tokenClaim.waterfall.waterfallFunds();
            address token = tokenClaim.waterfall.token();
            token._safeTransfer(receiver, token._balanceOf(address(this)));

            splitMain.distributeETH(
                address(tokenClaim.split),
                tokenClaim.configuration.accounts,
                tokenClaim.configuration.percentAllocations,
                tokenClaim.configuration.distributorFee,
                address(0)
            );
            ERC20[] memory emptyTokens = new ERC20[](0);
            splitMain.withdraw(address(this), 1, emptyTokens);
            token._safeTransfer(receiver, token._balanceOf(address(this)));

            unchecked {
                ++i;
            }
        }
    }

    function name() external view returns (string memory) {
        return string.concat("Obol Liquid Waterfall Split ", utils.shortAddressToString(address(this)));
    }
}
