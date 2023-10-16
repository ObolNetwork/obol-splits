// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ISplitMain} from "../interfaces/ISplitMain.sol";
import {Clone} from "solady/utils/Clone.sol";

/// @author Obol
/// @dev Deploys a contract that can update a split should be called once as the
/// configuration is defined at deployment and cannot change
contract ImmutableSplitController is Clone {
  /// @notice IMSC already initialized
  error Initialized();

  /// @notice
  error Unauthorized();

  /// @notice Revert if split balance is > 1
  /// @dev Prevent distribution of current balance
  error Invalid_SplitBalance();

  /// -----------------------------------------------------------------------
  /// storage
  /// -----------------------------------------------------------------------

  /// -----------------------------------------------------------------------
  /// storage - constants
  /// -----------------------------------------------------------------------
  uint256 internal constant ADDRESS_BITS = 160;
  uint256 internal constant ONE_WORD = 32;

  /// -----------------------------------------------------------------------
  /// storage - cwia offsets
  /// -----------------------------------------------------------------------

  // splitMain (address, 20 bytes)
  // 0; first item
  uint256 internal constant SPLIT_MAIN_OFFSET = 0;
  // distributorFee (uint32, 4 bytes)
  // 1; second item
  uint256 internal constant DISTRIBUTOR_FEE_OFFSET = 20;
  // onwer (address, 20 bytes)
  // 2; third item
  uint256 internal constant OWNER_OFFSET = 24;
  // recipeints size (uint8, 1 byte )
  // 3; third item
  uint256 internal constant RECIPIENTS_SIZE_OFFSET = 44;
  // recipients data ()
  // 4; fourth item
  uint256 internal constant RECIPIENTS_OFFSET = 45;

  /// -----------------------------------------------------------------------
  /// storage - mutable
  /// -----------------------------------------------------------------------
  /// @dev Address of split to update
  address public split;

  constructor() {}

  function init(address splitAddress) external {
    if (split != address(0)) revert Initialized();

    split = splitAddress;
  }

  /// Updates split with the hardcoded configuration
  /// @dev Updates split with stored split configuration
  function updateSplit() external payable {
    if (msg.sender != owner()) revert Unauthorized();

    (address[] memory accounts, uint32[] memory percentAllocations) = getNewSplitConfiguration();

    // prevent distribution of existing money
    if (address(split).balance > 1) revert Invalid_SplitBalance();

    ISplitMain(splitMain()).updateSplit(split, accounts, percentAllocations, uint32(distributorFee()));
  }

  /// Address of SplitMain
  /// @dev equivalent to address public immutable splitMain;
  function splitMain() public pure returns (address) {
    return _getArgAddress(SPLIT_MAIN_OFFSET);
  }

  /// Fee charged by distributor
  /// @dev equivalent to address public immutable distributorFee;
  function distributorFee() public pure returns (uint256) {
    return _getArgUint32(DISTRIBUTOR_FEE_OFFSET);
  }

  /// Adress of owner
  /// @dev equivalent to address public immutable owner;
  function owner() public pure returns (address) {
    return _getArgAddress(OWNER_OFFSET);
  }

  // Returns unpacked recipients
  /// @return accounts Addresses to receive payments
  /// @return percentAllocations Percentage share for split accounts
  function getNewSplitConfiguration()
    public
    pure
    returns (address[] memory accounts, uint32[] memory percentAllocations)
  {
    // fetch the size first
    // then parse the data gradually
    uint256 size = _recipientsSize();
    accounts = new address[](size);
    percentAllocations = new uint32[](size);

    uint256 i = 0;
    for (; i < size;) {
      uint256 recipient = _getRecipient(i);
      accounts[i] = address(uint160(recipient));
      percentAllocations[i] = uint32(recipient >> ADDRESS_BITS);
      unchecked {
        i++;
      }
    }
  }

  /// Number of recipeints
  /// @dev  equivalent to address internal immutable _recipientsSize;
  function _recipientsSize() internal pure returns (uint256) {
    return _getArgUint8(RECIPIENTS_SIZE_OFFSET);
  }

  /// Gets recipient i
  /// @dev  emulates to uint256[] internal immutable recipient;
  function _getRecipient(uint256 i) internal pure returns (uint256) {
    unchecked {
      // shouldn't overflow
      return _getArgUint256(RECIPIENTS_OFFSET + (i * ONE_WORD));
    }
  }
}
