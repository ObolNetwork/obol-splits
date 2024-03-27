// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IETHPOSDeposit} from "src/interfaces/IETHPOSDeposit.sol";
import {IObolCapsule} from "src/interfaces/IObolCapsule.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";


contract ObolCapsule is IObolCapsule {

    using SafeTransferLib for ERC20;

    struct ValidatorInfo {
        // index of the validator in the beacon chain
        uint64 validatorIndex;
        // timestamp of the validator's most withdrawal
        uint64 mostRecentOracleWithdrawalTimestamp;
        // status of the validator
        bool status;
    }

    /// @notice This is the beacon chain deposit contract
    IETHPOSDeposit public immutable ethDepositContract;
    
    // STORAGE VARIABLES
    /// @notice The owner of this EigenPod
    address public podOwner;

    /// @notice address of a withdrawalAddress
    address public withdrawalAddress;

    /// @notice validator pubkey hash to information
    mapping (bytes32 => ValidatorInfo) public validators;

    constructor(IETHPOSDeposit _ethDepositContract) {
        ethDepositContract = _ethDepositContract;
    }

    /// @notice Used to initialize the pointers to addresses crucial to the pod's functionality. Called on construction by the EigenPodManager.
    function initialize(address _podOwner, address _withdrawalAddress) external {
        if (_podOwner != address(0)) revert InvalidAddress();
        if (podOwner != address(0)) revert AlreadyInitialized();

        podOwner = _podOwner;
        withdrawalAddress = _withdrawalAddress;

        emit Initialized(podOwner);
    }

    function stake(
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot
    ) external payable override onlyObolPodOwner {
        // @TODO is there a case for less than 32 ether deposits
        if (msg.value != 32 ether) revert InvalidStakeSize();
        ethDepositContract.deposit{value: 32 ether}(pubkey, _podWithdrawalCredentials(), signature, depositDataRoot);

        bytes32 pubkeyHash = keccak256(pubkey);

        emit ObolPodStaked(pubkey);

        validators[pubkeyHash] = ValidatorInfo(0, 0, true);
    }

    // @todo mapping of index => stateroot => block height
    function withdraw(
      uint64 oracleTimestamp,
      BeaconChainProofs.StateRootProof calldata stateRootProof,
      BeaconChainProofs.WithdrawalProof[] calldata withdrawalProofs,
      bytes[] calldata validatorFieldsProofs,
      bytes32[][] calldata validatorFields,
      bytes32[][] calldata withdrawalFields
    ) external {
        
        
    }

    modifier onlyObolPodOwner() {
        require(msg.sender == podOwner, "EigenPod.onlyEigenPodOwner: not podOwner");
        _;
    }

    function _podWithdrawalCredentials() internal view returns (bytes memory) {
        return abi.encodePacked(bytes1(uint8(1)), bytes11(0), address(this));
    }

    function rescueFunds(address token, uint256 amount) external {
        if (amount > 0) ERC20(token).safeTransfer(withdrawalAddress, amount);
    }

    function getBeaconBlockRootAtTimestamp(uint256 timestamp) public view returns (bytes32 beaconBlockRoot) {
        assembly {
            // beaconBlockRoot :=  
        }
    }
}
