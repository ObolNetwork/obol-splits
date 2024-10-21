// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ISymPod} from "src/symbiotic/SymPodStorageV1.sol";
import {IERC4626} from "src/interfaces/ISymPod.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Multicall} from "openzeppelin/utils/Multicall.sol";

/// @title SymPodSlasher
/// @author Obol
/// @notice Burner contract for integration into Symbiotic
contract SymPodSlasher is Multicall {
  event TriggerWithdrawal(address sender, address symPod, uint256 sharesToBurn, bytes32 withdrawalKey);

  event TriggerBurn(address sender, address symPod, uint256 amountBurned, bytes32 withdrawalKey);

  constructor() {}

  receive() external payable {}

  /// @notice Trigger withdrawal from a SymPod contract
  /// @dev Slashes the SymPod contract by initiating a withdrawal
  /// that is not delayed
  /// @param symPod symPod contract
  function triggerWithdrawal(ISymPod symPod) external returns (bytes32 withdrawalKey) {
    uint256 amountOfShares = ERC20(address(symPod)).balanceOf(address(this));
    uint256 amountWei = IERC4626(address(symPod)).convertToAssets(amountOfShares);

    withdrawalKey = symPod.onSlash(amountWei);

    emit TriggerWithdrawal(msg.sender, address(symPod), amountOfShares, withdrawalKey);
  }

  /// @notice Trigger a burn on funds received
  /// @dev Finalizes withdrawal from a SymPod contract and sends it to
  /// 0x0 address.
  /// @param symPod symPod to finalize withdrwawal
  /// @param withdrawalKey the withdrawal key
  function triggerBurn(ISymPod symPod, bytes32 withdrawalKey) external {
    uint256 amount = symPod.completeWithdraw(withdrawalKey);
    // send to burn address
    payable(address(0x0)).transfer(amount);

    emit TriggerBurn(msg.sender, address(symPod), amount, withdrawalKey);
  }
}
