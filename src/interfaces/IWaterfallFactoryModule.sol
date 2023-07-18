// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IWaterfallFactoryModule {
  /// Create a new WaterfallModule clone
  /// @param token Address of ERC20 to waterfall (0x0 used for ETH)
  /// @param nonWaterfallRecipient Address to recover non-waterfall tokens to
  /// @param recipients Addresses to waterfall payments to
  /// @param thresholds Absolute payment thresholds for waterfall recipients
  /// (last recipient has no threshold & receives all residual flows)
  /// @return wm Address of new WaterfallModule clone
  function createWaterfallModule(
    address token,
    address nonWaterfallRecipient,
    address[] calldata recipients,
    uint256[] calldata thresholds
  ) external returns (address);
}
