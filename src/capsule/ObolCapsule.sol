// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {Clone} from "solady/utils/Clone.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IETHPOSDeposit} from "src/interfaces/IETHPOSDeposit.sol";
import {IProofVerifier} from "src/interfaces/IProofVerifier.sol";
import {IObolCapsule} from "src/interfaces/IObolCapsule.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";
import {IObolCapsuleFactory} from "src/interfaces/IObolCapsuleFactory.sol";


/// @title ObolCapsule
/// @author Obol
/// @notice A composable state proof based staking contract
contract ObolCapsule is Clone, IObolCapsule {

    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------
    using SafeTransferLib for ERC20;

    struct ValidatorInfo {
        // timestamp of the validator's most withdrawal
        uint64 mostRecentOracleWithdrawalTimestamp;
        // status of the validator
        bool active;
    }

    /// -----------------------------------------------------------------------
    /// storage - constants & immutables
    /// -----------------------------------------------------------------------

    uint256 internal constant ADDRESS_BITS = 160;
    uint256 internal constant PERCENTAGE_SCALE = 1e5;
    uint256 internal constant ETH_STAKE_AMOUNT = 32 ether;

    /// @dev beacon roots contract
    address public constant BEACON_BLOCK_ROOTS_CONTRACT = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;

    /// @notice This is the beacon chain deposit contract
    IETHPOSDeposit public immutable ethDepositContract;

    /// @notice capsule factory
    IObolCapsuleFactory public immutable capsuleFactory;

    /// @notice fee share
    uint256 public immutable feeShare;

    /// @notice fee recipient
    address public immutable feeRecipient;

    /// -----------------------------------------------------------------------
    /// storage - cwia offsets
    /// -----------------------------------------------------------------------
    
    // principalRecipient (address, 20 bytes),
    // rewardRecipient (address, 20 bytes),

    // 0; first item
    uint256 internal constant PRINCIPAL_RECIPIENT_ADDRESS_OFFSET = 0;
    // 20 = recoveryAddress_offset (0) + recoveryAddress_size (address, 20
    // bytes)
    uint256 internal constant REWARD_RECIPIENT_ADDRESS_OFFSET = 20;
    
    /// -----------------------------------------------------------------------
    /// storage
    /// -----------------------------------------------------------------------

    /// @notice validator pubkey hash to information
    mapping (bytes32 => ValidatorInfo) public validators;


    constructor(
        IETHPOSDeposit _ethDepositContract,
        IObolCapsuleFactory factory,
        address _feeRecipient,
        uint256 _feeShare
    ) {
        if (_feeShare >= PERCENTAGE_SCALE) revert Invalid_FeeShare(_feeShare);
        if (_feeShare > 0 && _feeRecipient == address(0)) revert Invalid_FeeRecipient();

        ethDepositContract = _ethDepositContract;
        capsuleFactory = factory;
        feeShare = _feeShare;
        feeRecipient = _feeRecipient;
    }

    /// @notice Create new validators
    /// @param pubkeys validator public keys
    /// @param signatures deposit validator signatures
    /// @param depositDataRoots deposit validator data roots
    function stake(
        bytes[] calldata pubkeys,
        bytes[] calldata signatures,
        bytes32[] depositDataRoots
    ) external payable override {
        uint256 size = pubkeys.length;
        if (pubkeys.length != signatures.length != depositDataRoots.length) 
            revert InvalidCallData();
        if (msg.value != ETH_STAKE_AMOUNT * size) revert InvalidStakeSize();

        uint256 i = 0;
        for(i; i < size;) {
            ethDepositContract.deposit{value: ETH_STAKE_AMOUNT}(
                pubkeys[i], 
                capsuleWithdrawalCredentials(), 
                signatures[i], 
                depositDataRoots[i]
            );
            
            emit ObolPodStaked(pubkeys[i]);

            unchecked {
                i++;
            }
            bytes32 pubkeyHash = keccak256(pubkeys[i]);
            validators[pubkeyHash] = ValidatorInfo(0, true);
        }
    }

    /// @notice Create new validators
    /// @param oracleTimestamp oracle timestamp 


    /// How large is the proof 
    // 
    // do for 1 single validator first in one block
    //
    // then figure out for multiple validators in one block

    // then figure out for multiple validators in multiple blocks

    function withdraw(
        uint64 oracleTimestamp,
        bytes calldata proof
    ) external {
        IProofVerifier proofVerifier = capsuleFactory.getProofVerifier();

        if (proofVerifier.isValidWithdrawalProof(proof) == false) {
            revert InvalidProof();
        }

        uint256 i = 0;
        for(i; i < size;) {
            ValidatorInfo storage info = validators[pubkeyHashes[i]];

            info.mostRecentOracleWithdrawalTimestamp = uint64(oracleTimestamp);
        }

        // update the latest timestamp 
        ValidatorInfo storage validatorInfo = validators[pubkeyHashes];
        validatorInfo.mostRecentOracleWithdrawalTimestamp = uint64(oracleTimestamp);
        // process withdrawal

        // emit event
        emit Withdraw();
    }

    /// @notice Recover funds
    /// @param token Token to send recover
    /// @param amount amount of tokens to recover
    function rescueFunds(address token, uint256 amount) external {
        if (amount > 0) ERC20(token).safeTransfer(rewardRecipient(), amount);
    }

    /// @dev Verify withdrawal proof
    function verfiyWithdrawalProof(

    ) public view returns (bool valid) {

    }

    /// Address that receives rewards
    /// @dev equivalent to address public immutable rewardRecipient;
    function rewardRecipient() public pure returns(address) {
        return _getArgAddress(REWARD_RECIPIENT_ADDRESS_OFFSET);
    }

    /// Address that receives rewards
    /// @dev equivalent to address public immutable principalRecipient;
    function principalRecipient() public pure returns (address) {
        return _getArgAddress(PRINCIPAL_RECIPIENT_ADDRESS_OFFSET);
    }

    /// @dev Encodes withdrawal credentials
    function capsuleWithdrawalCredentials() public view returns (bytes memory) {
        return abi.encodePacked(bytes1(uint8(1)), bytes11(0), address(this));
    }

    /// @dev Returns the becaon block root based on timestamp
    /// @param timestamp timestamp to fetch state root 
    /// @return stateRoot beacon state root 
    function getRootFromTimestamp(uint256 timestamp) public view returns (bytes32 stateRoot) {
        (bool ret, bytes memory data) = BEACON_BLOCK_ROOTS_CONTRACT.call(bytes.concat(bytes32(timestamp)));
        if (ret == false) revert Invalid_Timestamp(timestamp);

        stateRoot = bytes32(data);
    }

    function _verifyAndProcessWithdrawal(

    ) internal {
        
    }
}
