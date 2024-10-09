// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import {ISymPod} from "src/symbiotic/SymPodStorageV1.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract SymPodBurner {

    event TriggerWithdrawal(
        address sender,
        address symPod,
        uint256 sharesToBurn,
        bytes32 withdrawalKey
    );

    event TriggerBurn(
        address sender,
        address symPod,
        uint256 amountBurned,
        bytes32 withdrawalKey
    );

    constructor() {

    }
    
    receive() external payable {}

    function triggerWithdrawal(ISymPod symPod) external {
        uint256 amountOfShares = ERC20(address(symPod)).balanceOf(address(this));
        // IERC20(symPod).approve(, type(uint256).max);
        (bytes32 withdrawalKey, ) = symPod.onSlash(amountOfShares, uint48(block.timestamp));

        emit TriggerWithdrawal(msg.sender, address(symPod), amountOfShares, withdrawalKey);
    }

    function triggerBurn(ISymPod symPod, bytes32 withdrawalKey) external {
        uint256 amount = symPod.completeWithdraw(withdrawalKey);
        // send to burn address
        payable(address(0x0)).transfer(amount);

        emit TriggerBurn(msg.sender, address(symPod), amount, withdrawalKey);
    }

}