// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;
import {ERC20} from 'solmate/tokens/ERC20.sol';
import {SafeTransferLib} from 'solmate/utils/SafeTransferLib.sol';
import {Clone} from "solady/utils/Clone.sol";

interface IwSTETH {
    function wrap(uint256 amount) external returns (uint256);
}

contract LidoSplit is Clone {
    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------
    using SafeTransferLib for ERC20;

    /// -----------------------------------------------------------------------
    /// storage - cwia offsets
    /// -----------------------------------------------------------------------

    // stETH (address, 20 bytes),
    // 0; first item
    uint256 internal constant ST_ETH_ADDRESS_OFFSET = 0;
    // 1; second item
    uint256 internal constant WST_ETH_ADDRESS_OFFSET = 20;
    // 2; third item
    uint256 internal constant SPLIT_WALLET_ADDRESS_OFFSET = 40;

    constructor() {}

    function _getSplitWallet() internal pure returns (address) {
        return _getArgAddress(SPLIT_WALLET_ADDRESS_OFFSET);
    }

    function _getstETHAddress() internal pure returns (address) {
        return _getArgAddress(ST_ETH_ADDRESS_OFFSET);
    }

    function _getwstETHAddress() internal pure returns (address) {
        return _getArgAddress(WST_ETH_ADDRESS_OFFSET);
    }

    function distribute() external returns(uint256 amount) {
        ERC20 stETH = ERC20(_getstETHAddress());
        ERC20 wstETH = ERC20(_getwstETHAddress());


        uint256 balance = stETH.balanceOf(address(this));
        // approve the wstETH
        stETH.approve(address(wstETH), balance);
        amount = IwSTETH(address(wstETH)).wrap(balance);
        ERC20(wstETH).safeTransfer(_getSplitWallet(), amount);
    }
}