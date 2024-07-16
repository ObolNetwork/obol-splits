// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import {IETHPOSDeposit} from "src/interfaces/IETHPOSDeposit.sol";
import {IProofVerifier} from "src/interfaces/IProofVerifier.sol";
import {IObolCapsuleFactory} from "src/interfaces/IObolCapsuleFactory.sol";
import {ObolCapsule} from "src/capsule/ObolCapsule.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {BeaconProxy} from "openzeppelin/proxy/beacon/BeaconProxy.sol";
import {Create2} from "openzeppelin/utils/Create2.sol";


/// @title ObolCapsuleFactory
/// @author Obol
/// @notice A factory contract for cheaply deploying ObolCapsule
contract ObolCapsuleFactory is Ownable, IObolCapsuleFactory {

    /// @notice capsule implementation
    ObolCapsule public immutable capsuleImplementation;

    /// @dev number of address bits
    uint256 internal constant ADDRESS_BITS = 160;

    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------

    using LibClone for address;

    /// -----------------------------------------------------------------------
    /// storage
    /// -----------------------------------------------------------------------

    address public immutable obolCapsuleBeacon;

    constructor(
        address _obolCapsuleBeacon,
        address _ethDepositContract,
        uint256 _genesisTime,
        address _owner,
        address _feeRecipient,
        uint256 _feeShare,
        uint56 _becaonChainGenesisTime
    ) {
        _initializeOwner(_owner);

        capsuleImplementation = new ObolCapsule(
            IETHPOSDeposit(_ethDepositContract),
            _genesisTime,
            _feeRecipient,
            _feeShare
        );

        obolCapsuleBeacon = _obolCapsuleBeacon;
    }

    /// Create a new OptimisticWithdrawalRecipient clone
    /// @param principalRecipient Address to distribute principal payments to
    /// @param rewardRecipient Address to distribute reward payments to
    /// @param recoveryRecipient Address to recover tokens to 
    function createCapsule(
        address principalRecipient,
        address rewardRecipient,
        address recoveryRecipient
    ) external returns (address capsule) {
        /// checks
        
        if (rewardRecipient == address(0)) revert Invalid__RewardRecipient();
        if (principalRecipient == address(0)) revert Invalid__PrincipalRecipient();
        if (recoveryRecipient == address(0)) revert Invalid__RecoveryRecipient();

        // would not exceed contract size limits
        // important to not reorder
        bytes32 salt = _createSalt(principalRecipient, rewardRecipient, recoveryRecipient);

        capsule = Create2.deploy(
            0,
            salt,
            abi.encodePacked(type(BeaconProxy).creationCode, 
                abi.encode(obolCapsuleBeacon,  
                    abi.encodeWithSignature(
                        "initialize(address,address,address)",
                        principalRecipient,
                        rewardRecipient,
                        recoveryRecipient
                    )
                )
            )
        );
        
        emit CreateCapsule(
            capsule,
            principalRecipient,
            rewardRecipient,
            recoveryRecipient
        );
    }

    /// @notice Predict capsule address
    /// @param principalRecipient principal address to receive principal stake
    /// @param rewardRecipient reward addresss to receive rewards
    /// @param recoveryRecipient recovery address
    function predictCapsuleAddress(
        address principalRecipient,
        address rewardRecipient,
        address recoveryRecipient
    ) external view returns (address capsule) {
        bytes32 salt = _createSalt(principalRecipient, rewardRecipient, recoveryRecipient);
        capsule = Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(type(BeaconProxy).creationCode, 
                    abi.encode(obolCapsuleBeacon,  
                        abi.encodeWithSignature(
                            "initialize(address,address,address)",
                            principalRecipient,
                            rewardRecipient,
                            recoveryRecipient
                        )
                    )
                )
            )
        );
    }

    /// @dev creates salt and packs data
    function _createSalt(
        address principalRecipient,
        address rewardRecipient,
        address recoveryRecipient
    ) internal pure returns (bytes32 salt) {
        // would not exceed contract size limits
        // important to not reorder
        bytes memory data = abi.encodePacked(principalRecipient, rewardRecipient, recoveryRecipient);
        salt = keccak256(data);
    }

}