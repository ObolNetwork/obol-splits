// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import {IObolCapsule} from "src/interfaces/IObolCapsule.sol";
import {Clone} from "solady/utils/Clone.sol";


abstract contract ObolCapsuleStorageV1 is IObolCapsule, Clone {

    /// -----------------------------------------------------------------------
    /// storage
    /// -----------------------------------------------------------------------
    struct CapsuleData {
        /// @dev Last submitted exit epoch
        uint128 exitedStake;
        /// @dev pending amount of stake to claim
        uint128 pendingStakeToClaim;
    }
    
    /// @dev hardfork it supports
    string public HARDFORK;

    /// @notice validator pubkey hash to exit status
    mapping (uint256 index => uint256 map) internal exitedValidators;

    /// @notice Tracks capsule state
    CapsuleData public capsuleInfo;

}
