// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;
import {ISplitMain} from "../interfaces/ISplitMain.sol";
import {Clone} from "solady/utils/Clone.sol";


/// @author Obol
/// @dev Deploys a contract that can update a split should be called once as the 
/// configuration is defined at deployment and cannot change
contract ImmutableSplitController is Clone {

    /// -----------------------------------------------------------------------
    /// errors
    /// -----------------------------------------------------------------------
    
    /// @notice IMSC already initialized
    error Initialized();

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
    // // split (address, 20 bytes)
    // // 1; second item
    // uint256 internal constant SPLIT_ADDRESS_OFFSET = 20;
    // distributorFee (uint32, 4 bytes)
    // 2; third item
    uint256 internal constant DISTRIBUTOR_FEE_OFFSET = 20;
    // recipeints size (uint8, 1 byte )
    // 3; fourth item
    uint256 internal constant RECIPIENTS_SIZE_OFFSET = 24;
    // recipients data ()
    // 4; fifth item
    uint256 internal constant RECIPIENTS_OFFSET = 25;

    /// -----------------------------------------------------------------------
    /// storage - mutable
    /// -----------------------------------------------------------------------
    address public split;


    constructor() {}

    function init(address _split) external {
        if (_split != address(0)) revert Initialized();

        split = _split;
    }

    /// Updates split with the hardcoded configuration
    /// @dev Updates split with stored split configuration
    function updateSplit() external payable {
        // @TODO accept control
        address _splitMain = splitMain();
        address _split = split;
        uint32 _distributorFee = uint32(distributorFee());

        (
            address[] memory accounts,
            uint32[] memory percentAllocations
        ) = getNewSplitConfiguration();

        ISplitMain(_splitMain).updateSplit(
            _split,
            accounts,
            percentAllocations,
            _distributorFee
        );
    }

    /// Address of SplitMain
    /// @dev equivalent to address public immutable splitMain;
    function splitMain() public pure returns (address) {
        return _getArgAddress(SPLIT_MAIN_OFFSET);
    }

    // /// Address of split to update
    // /// @dev equivalent to address public immutable split;
    // function split() public pure returns (address) {
    //     return _getArgAddress(SPLIT_ADDRESS_OFFSET);
    // }

    /// Fee charged by distributor
    /// @dev equivalent to address public immutable distributorFee;
    function distributorFee() public pure returns(uint256) {
        return _getArgUint32(DISTRIBUTOR_FEE_OFFSET);
    }

    // Returns unpacked recipients
    /// @return accounts Addresses to receive payments
    /// @return percentAllocations Percentage share for split accounts
    function getNewSplitConfiguration() public pure returns (
        address[] memory accounts,
        uint32[] memory percentAllocations
    ) {
        // fetch the size first
        // then parse the data gradually
        uint256 size = _recipientsSize();
        accounts = new address[](size);
        percentAllocations = new uint32[](size);

        uint i;
        for (i; i < size;) {
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