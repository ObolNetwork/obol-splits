// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

abstract contract SplitterConfiguration {
  /// @dev invalid split accounts configuration
  error InvalidSplit__TooFewAccounts(uint256 accountsLength);
  /// @notice Array lengths of accounts & percentAllocations don't match
  /// (`accountsLength` != `allocationsLength`)
  /// @param accountsLength Length of accounts array
  /// @param allocationsLength Length of percentAllocations array
  error InvalidSplit__AccountsAndAllocationsMismatch(uint256 accountsLength, uint256 allocationsLength);
  /// @notice Invalid percentAllocations sum `allocationsSum` must equal
  /// `PERCENTAGE_SCALE`
  /// @param allocationsSum Sum of percentAllocations array
  error InvalidSplit__InvalidAllocationsSum(uint32 allocationsSum);
  /// @notice Invalid accounts ordering at `index`
  /// @param index Index of out-of-order account
  error InvalidSplit__AccountsOutOfOrder(uint256 index);
  /// @notice Invalid percentAllocation of zero at `index`
  /// @param index Index of zero percentAllocation
  error InvalidSplit__AllocationMustBePositive(uint256 index);
  /// @notice Invalid distributorFee `distributorFee` cannot be greater than
  /// 10% (1e5)
  /// @param distributorFee Invalid distributorFee amount
  error InvalidSplit__InvalidDistributorFee(uint32 distributorFee);
  /// @notice Array of accounts size
  /// @param size acounts size
  error InvalidSplit__TooManyAccounts(uint256 size);

  uint256 internal constant PERCENTAGE_SCALE = 1e6;
  uint256 internal constant MAX_DISTRIBUTOR_FEE = 1e5;

  struct JsonSplitData {
    address[] accounts;
    address controller;
    uint32 distributorFee;
    uint32[] percentAllocations;
  }

  function _validateSplitInputJson(JsonSplitData[] memory configuration) internal pure {
    for (uint256 i = 0; i < configuration.length; i++) {
      address[] memory splitAddresses = configuration[i].accounts;
      uint32[] memory percents = configuration[i].percentAllocations;
      uint32 distributorFee = configuration[i].distributorFee;
      _validSplit(splitAddresses, percents, distributorFee);
    }
  }

  function _validateSplitInputJson(JsonSplitData memory configuration) internal pure {
    address[] memory splitAddresses = configuration.accounts;
    uint32[] memory percents = configuration.percentAllocations;
    uint32 distributorFee = configuration.distributorFee;
    _validSplit(splitAddresses, percents, distributorFee);
  }

  function _validSplit(address[] memory accounts, uint32[] memory percentAllocations, uint32 distributorFee)
    internal
    pure
  {
    if (accounts.length < 2) revert InvalidSplit__TooFewAccounts(accounts.length);
    if (accounts.length != percentAllocations.length) {
      revert InvalidSplit__AccountsAndAllocationsMismatch(accounts.length, percentAllocations.length);
    }
    // _getSum should overflow if any percentAllocation[i] < 0
    if (_getSum(percentAllocations) != PERCENTAGE_SCALE) {
      revert InvalidSplit__InvalidAllocationsSum(_getSum(percentAllocations));
    }
    unchecked {
      // overflow should be impossible in for-loop index
      // cache accounts length to save gas
      uint256 loopLength = accounts.length - 1;
      for (uint256 i = 0; i < loopLength; ++i) {
        // overflow should be impossible in array access math
        if (accounts[i] >= accounts[i + 1]) revert InvalidSplit__AccountsOutOfOrder(i);
        if (percentAllocations[i] == uint32(0)) revert InvalidSplit__AllocationMustBePositive(i);
      }
      // overflow should be impossible in array access math with validated
      // equal array lengths
      if (percentAllocations[loopLength] == uint32(0)) revert InvalidSplit__AllocationMustBePositive(loopLength);
    }
    if (distributorFee > MAX_DISTRIBUTOR_FEE) revert InvalidSplit__InvalidDistributorFee(distributorFee);
  }

  function _getSum(uint32[] memory percents) internal pure returns (uint32 sum) {
    for (uint32 i = 0; i < percents.length; i++) {
      sum += percents[i];
    }
  }
}