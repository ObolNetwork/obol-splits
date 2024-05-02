// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import {IETHPOSDeposit} from "src/interfaces/IETHPOSDeposit.sol";
import {IProofVerifier} from "src/interfaces/IProofVerifier.sol";
import {IObolCapsuleFactory} from "src/interfaces/IObolCapsuleFactory.sol";
import {ObolCapsule} from "src/capsule/ObolCapsule.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {StateProofVerifierV1} from "src/capsule/verifiers/StateProofVerifierV1.sol";


/// @title ObolCapsuleFactory
/// @author Obol
/// @notice A factory contract for cheaply deploying ObolCapsule

contract ObolCapsuleFactory is Ownable, IObolCapsuleFactory {

    /// @notice capsule implementation
    ObolCapsule public immutable capsuleImplementation;

    uint256 internal constant ADDRESS_BITS = 160;

    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------

    using LibClone for address;

    /// -----------------------------------------------------------------------
    /// storage
    /// -----------------------------------------------------------------------

    IProofVerifier public stateProofVerifier;

    constructor(
        IETHPOSDeposit _ethDepositContract,
        address _owner,
        address _feeRecipient,
        uint256 _feeShare
    ) {
        _initializeOwner(_owner);

        capsuleImplementation = new ObolCapsule(
            _ethDepositContract,
            address(this),
            _feeRecipient,
            _feeShare
        );

        stateProofVerifier = new StateProofVerifierV1{
            salt: keccak256("obol.verifier.v1")
        }();
    }

    /// Create a new OptimisticWithdrawalRecipient clone
    /// @param principalRecipient Address to distribute principal payments to
    /// @param rewardRecipient Address to distribute reward payments to
    function createCapsule(
        address rewardRecipient,
        address principalRecipient
    ) external returns (address capsule) {
        /// checks
        
        if (rewardRecipient == address(0)) revert Invalid__RewardRecipient();
        if (principalRecipient == address(0)) revert Invalid__PrincipalRecipient();

        // would not exceed contract size limits
        // important to not reorder
        bytes memory data = abi.encodePacked(principalRecipient, rewardRecipient);

        capsule = address(capsuleImplementation).clone(data);

        emit CreateCapsule(
            capsule,
            principalRecipient,
            rewardRecipient
        );
    }

    /// @notice Sets a new state proof verifier contract
    /// @param newVerifier address of newVerifier contract
    function setNewVerifier(address newVerifier) external onlyOwner {
        if (newVerifier == address(0)) revert Invalid__Address();

        address oldVerifier = stateProofVerifier;
        stateProofVerifier = newVerifier;

        emit UpdateStateProofVerifier(
            oldVerifier,
            newVerifier,
            block.timestamp
        );
    }

    /// @notice Returns address of the verifier contract
    /// @return Address of verifier contract
    function getVerifier() external returns (address) {
        return address(stateProofVerifier);
    }

}