// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ISplitMain} from "../interfaces/ISplitMain.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {ImmutableSplitController} from "./ImmutableSplitController.sol";

/// @author Obol
/// @dev Deploys ImmutableSplitController cheaply using cwia clones
contract ImmutableSplitControllerFactory {
  /// @dev invalid address
  error Invalid_Address();
  /// @dev invalid owner address
  error Invalid_Owner();
  /// @dev invalid split address
  error InvalidSplit_Address();
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

  /// -----------------------------------------------------------------------
  /// libraries
  /// -----------------------------------------------------------------------

  using LibClone for address;

  /// -----------------------------------------------------------------------
  /// events
  /// -----------------------------------------------------------------------

  /// Emitted after a new IMSC is deployed
  /// @param controller Address of newly created IMSC clone
  /// @param split Address of split
  /// @param owner Adderss of the owner of the controller
  /// @param accounts Addresses of
  /// @param percentAllocations Addresses to recover non-waterfall tokens to
  /// @param distributorFee Amount of
  event CreateIMSC(
    address indexed controller,
    address indexed split,
    address owner,
    address[] accounts,
    uint32[] percentAllocations,
    uint256 distributorFee
  );

  /// -----------------------------------------------------------------------
  /// storage
  /// -----------------------------------------------------------------------

  /// -----------------------------------------------------------------------
  /// storage - constants & immutables
  /// -----------------------------------------------------------------------
  uint256 internal constant ADDRESS_BITS = 160;
  /// @notice constant to scale uints into percentages (1e6 == 100%)
  uint256 public constant PERCENTAGE_SCALE = 1e6;
  /// @notice maximum distributor fee; 1e5 = 10% * PERCENTAGE_SCALE
  uint256 internal constant MAX_DISTRIBUTOR_FEE = 1e5;

  /// @dev splitMain address
  address public immutable splitMain;

  /// @dev Implementation of ImmutableSplitController
  ImmutableSplitController public immutable controller;

  /// -----------------------------------------------------------------------
  /// modifiers
  /// -----------------------------------------------------------------------
  modifier validSplit(address[] memory accounts, uint32[] memory percentAllocations, uint32 distributorFee) {
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
    _;
  }

  /// Creates Factory
  /// @dev initializes the factory
  /// @param splitMain_ Address of splitMain
  constructor(address splitMain_) {
    if (splitMain_ == address(0)) revert Invalid_Address();

    splitMain = splitMain_;
    controller = new ImmutableSplitController();
    // this is to prevent the initialization of the
    // implementation contract by external actors
    controller.init(address(1));
  }

  /// Deploys a new immutable controller
  /// @dev Create a new immutable split controller
  /// @param split Address of the split to create a controller for
  /// @param owner Address that can call the updateSplit(..) function
  /// @param accounts Ordered, unique list of addresses with ownership in the
  /// split
  /// @param percentAllocations  Percent allocations associated with each
  /// address
  /// @param distributorFee Distributor fee share
  /// @param deploymentSalt salt to use for deterministic deploy
  function createController(
    address split,
    address owner,
    address[] calldata accounts,
    uint32[] calldata percentAllocations,
    uint32 distributorFee,
    bytes32 deploymentSalt
  ) external validSplit(accounts, percentAllocations, distributorFee) returns (ImmutableSplitController newController) {
    if (split == address(0)) revert InvalidSplit_Address();

    if (owner == address(0)) revert Invalid_Owner();

    newController = ImmutableSplitController(
      address(controller).cloneDeterministic(
        _packSplitControllerData(owner, accounts, percentAllocations, distributorFee), deploymentSalt
      )
    );

    // initialize with split address
    newController.init(split);

    emit CreateIMSC(address(controller), split, owner, accounts, percentAllocations, distributorFee);
  }

  /// @notice Predicts the address for an immutable split controller created
  /// with
  /// recipients `accounts` with ownerships `percentAllocations`
  /// and a keeper fee for splitting of `distributorFee`
  /// @param accounts Ordered, unique list of addresses with ownership in the
  /// split
  /// @param percentAllocations Percent allocations associated with each
  /// address
  /// @param distributorFee Keeper fee paid by split to cover gas costs of
  /// distribution
  /// @param deploymentSalt Salt to use to deploy
  /// @return splitController Predicted address of such a split controller
  function predictSplitControllerAddress(
    address owner,
    address[] calldata accounts,
    uint32[] calldata percentAllocations,
    uint32 distributorFee,
    bytes32 deploymentSalt
  ) external view returns (address splitController) {
    splitController = address(controller).predictDeterministicAddress(
      _packSplitControllerData(owner, accounts, percentAllocations, distributorFee), deploymentSalt, address(this)
    );
  }

  /// @dev Packs split controller data
  /// @param accounts Ordered, unique list of addresses with ownership in the
  /// split
  /// @param percentAllocations Percent allocations associated with each
  /// address
  /// @param distributorFee Keeper fee paid by split to cover gas costs of
  /// distribution
  function _packSplitControllerData(
    address owner,
    address[] calldata accounts,
    uint32[] calldata percentAllocations,
    uint32 distributorFee
  ) internal view returns (bytes memory data) {
    uint256 recipientsSize = accounts.length;
    if (recipientsSize > type(uint8).max) revert InvalidSplit__TooManyAccounts(recipientsSize);

    uint256[] memory recipients = new uint256[](recipientsSize);

    uint256 i = 0;
    for (; i < recipientsSize;) {
      recipients[i] = (uint256(percentAllocations[i]) << ADDRESS_BITS) | uint256(uint160(accounts[i]));

      unchecked {
        i++;
      }
    }

    data = abi.encodePacked(splitMain, distributorFee, owner, uint8(recipientsSize), recipients);
  }

  /// @notice Sums array of uint32s
  /// @param numbers Array of uint32s to sum
  /// @return sum Sum of `numbers`.
  function _getSum(uint32[] memory numbers) internal pure returns (uint32 sum) {
    // overflow should be impossible in for-loop index
    uint256 numbersLength = numbers.length;
    for (uint256 i = 0; i < numbersLength;) {
      sum += numbers[i];
      unchecked {
        // overflow should be impossible in for-loop index
        ++i;
      }
    }
  }
}
