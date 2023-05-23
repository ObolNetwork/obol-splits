// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {Clone} from "solady/utils/Clone.sol";
import {ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {TokenUtils} from "splits-utils/TokenUtils.sol";
import {ILiquidWaterfall} from "../../interfaces/ILiquidWaterfall.sol";


/// @title Pass-Through Wallet Implementation
/// @author 0xSplits
/// @notice A clone-implementation of a pass-through wallet.
/// Please be aware, owner has _FULL CONTROL_ of the deployment.
/// @dev This contract uses token = address(0) to refer to ETH.
contract WalletImpl is ERC1155TokenReceiver, ERC721TokenReceiver, Clone {
    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------

    using TokenUtils for address;

    /// -----------------------------------------------------------------------
    /// storage - cwia offsets
    /// -----------------------------------------------------------------------

    // 0; first item
    uint256 internal constant TOKEN_ADDRESS_OFFSET = 0;

    /// 1; second item
    uint256 internal constant TOKEN_ID_OFFSET = 20;

    /// -----------------------------------------------------------------------
    /// structs
    /// -----------------------------------------------------------------------
    
    struct Call {
        address to;
        uint256 value;
        bytes data;
    }

    /// -----------------------------------------------------------------------
    /// events
    /// -----------------------------------------------------------------------
    event ExecCalls(Call[] calls);

    // emitted in clone bytecode
    event ReceiveETH(uint256 amount);

    /// -----------------------------------------------------------------------
    /// storage
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// storage - mutables
    /// -----------------------------------------------------------------------
    /// -----------------------------------------------------------------------
    /// constructor & initializer
    /// -----------------------------------------------------------------------

    constructor() {
    }

    /// -----------------------------------------------------------------------
    /// functions
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// functions - public & external - onlyOwner
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// functions - public & external - permissionless
    /// -----------------------------------------------------------------------

    /// emit event when receiving ETH
    /// @dev implemented w/i clone bytecode
    /* receive() external payable { */
    /*     emit ReceiveETH(msg.value); */
    /* } */

    /// send tokens_ to $passThrough
    function passThroughTokens(address[] calldata tokens_, address receiver) external returns (uint256[] memory amounts) {
        require(_isOwner(receiver), "unauthorized");
        
        uint256 length = tokens_.length;
        amounts = new uint256[](length);
        for (uint256 i; i < length;) {
            address token = tokens_[i];
            uint256 amount = token._balanceOf(address(this));
            amounts[i] = amount;
            token._safeTransfer(receiver, amount);

            unchecked {
                ++i;
            }
        }

        emit PassThrough(_passThrough, tokens_, amounts);
    }

        /// allow owner to execute arbitrary calls
    function execCalls(Call[] calldata calls_)
        external
        payable
        onlyOwner
        returns (uint256 blockNumber, bytes[] memory returnData)
    {
        blockNumber = block.number;
        uint256 length = calls_.length;
        returnData = new bytes[](length);

        bool success;
        for (uint256 i; i < length;) {
            Call calldata calli = calls_[i];
            (success, returnData[i]) = calli.to.call{value: calli.value}(calli.data);
            require(success, string(returnData[i]));

            unchecked {
                ++i;
            }
        }

        emit ExecCalls(calls_);
    }

    function _getTokenAddress() internal pure returns(address) {
        return _getArgAddress(TOKEN_ADDRESS_OFFSET);
    }

    function _getTokenID() internal pure returns(uint256) {
        return _getArgUint256(TOKEN_ID_OFFSET);
    }

    function _isOwner(address sender) internal returns (bool) {
        // get the owner of the token id of the NFT
        return ILiquidWaterfall(_getTokenAddress()).balanceOf(sender, _getTokenID()) > 0;
    }

    modifier onlyOwner() {
        require(_isOwner(msg.sender), "unauthorized");
        _;
    }
}