// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import {IObolCapsule} from "src/interfaces/IObolCapsule.sol";
import {Clone} from "solady/utils/Clone.sol";
import {StateProofVerifierV1} from "src/capsule/verifiers/StateProofVerifierV1.sol";
import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";


abstract contract ObolCapsuleStorageV1 is StateProofVerifierV1, Initializable, IObolCapsule {

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

    /// @dev Address that receives stake share
    address public principalRecipient;

    /// @dev Address that receives rewards
    address public rewardRecipient;

    /// @dev Address to recover tokens to
    address public recoveryAddress;

    /// @notice validator pubkey hash to exit status
    mapping (uint256 index => uint256 map) internal exitedValidators;

    /// @notice Tracks capsule state
    CapsuleData public capsuleInfo;

}
