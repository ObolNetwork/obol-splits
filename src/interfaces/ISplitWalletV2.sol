// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {ISplitFactoryV2} from "./ISplitFactoryV2.sol";

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

  /**
   * @notice Distributes the tokens in the split & Warehouse to the recipients.
   * @dev The split must be initialized and the hash of _split must match splitHash.
   * @param _split The split struct containing the split data that gets distributed.
   * @param _token The token to distribute.
   * @param _distributor The distributor of the split.
   */
  function distribute(ISplitFactoryV2.Split calldata _split, address _token, address _distributor) external;
}
