// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import {IETHPOSDeposit} from "src/interfaces/IETHPOSDeposit.sol";
import {IProofVerifier} from "src/interfaces/IProofVerifier.sol";
import {IObolCapsuleFactory} from "src/interfaces/IObolCapsuleFactory.sol";
import {ObolCapsule} from "src/capsule/ObolCapsule.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {StateProofVerifierV1} from "src/verifiers/StateProofVerifierV1.sol";


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

    IProofVerifier public stateProofVerifier;

    constructor(
        address _ethDepositContract,
        address _owner,
        address _feeRecipient,
        uint256 _feeShare,
        uint56 _becaonChainGenesisTime
    ) {
        _initializeOwner(_owner);

        capsuleImplementation = new ObolCapsule(
            IETHPOSDeposit(_ethDepositContract),
            IObolCapsuleFactory(address(this)),
            _feeRecipient,
            _feeShare
        );

        stateProofVerifier = new StateProofVerifierV1{
            salt: keccak256("obol.verifier.v1")
        }(_becaonChainGenesisTime);
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
        (bytes memory data, bytes32 salt) = _createSaltAndPackData(principalRecipient, rewardRecipient, recoveryRecipient);

        capsule = address(capsuleImplementation).cloneDeterministic(data, salt);
        
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
        (bytes memory data, bytes32 salt) = _createSaltAndPackData(
            principalRecipient,
            rewardRecipient,
            recoveryRecipient
        );

        capsule = address(capsuleImplementation).predictDeterministicAddress(
            data,
            salt,
            address(this)
        );
    }

    /// @notice Sets a new state proof verifier contract
    /// @param newVerifier address of newVerifier contract
    function setNewVerifier(address newVerifier) external onlyOwner {
        /// @TODO make it timestamp activated new verifier
        /// this aligns with hardfork timestamps

        if (address(newVerifier) == address(0)) revert Invalid__Address();

        IProofVerifier oldVerifier = stateProofVerifier;
        stateProofVerifier = IProofVerifier(newVerifier);

        emit UpdateStateProofVerifier(
            address(oldVerifier),
            address(newVerifier)
        );
    }

    /// @notice Returns address of the verifier contract
    /// @return Address of verifier contract
    function getVerifier() external view override returns (IProofVerifier) {
        return stateProofVerifier;
    }

    /// @dev creates salt and packs data
    function _createSaltAndPackData(
        address principalRecipient,
        address rewardRecipient,
        address recoveryRecipient
    ) internal pure returns (bytes memory data, bytes32 salt) {
        // would not exceed contract size limits
        // important to not reorder
        data = abi.encodePacked(principalRecipient, rewardRecipient, recoveryRecipient);
        salt = keccak256(data);
    }

}