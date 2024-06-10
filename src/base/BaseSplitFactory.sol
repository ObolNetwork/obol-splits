// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

abstract contract BaseSplitFactory {
  /// -----------------------------------------------------------------------
  /// errors
  /// -----------------------------------------------------------------------
  /// @dev Invalid address
  error Invalid_Address();

  /// -----------------------------------------------------------------------
  /// events
  /// -----------------------------------------------------------------------
  /// Emitted on createCollector
  event CreateSplit(address token, address withdrawalAddress);

  function createCollector(address token, address withdrawalAddress) external virtual returns (address collector);
}
