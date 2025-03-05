// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

// Simplified interface for SplitWalletV2
// https://github.com/0xSplits/splits-contracts-monorepo/blob/main/packages/splits-v2/src/splitters/SplitWalletV2.sol
interface ISplitWalletV2 {
  /**
   * @notice Gets the native token address.
   * @return The native token address.
   */
  function NATIVE_TOKEN() external pure returns (address);

  /**
   * @notice Gets the total token balance of the split wallet and the warehouse.
   * @param _token The token to get the balance of.
   * @return splitBalance The token balance in the split wallet.
   * @return warehouseBalance The token balance in the warehouse of the split wallet.
   */
  function getSplitBalance(address _token) external view returns (uint256 splitBalance, uint256 warehouseBalance);
}
