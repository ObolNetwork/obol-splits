// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
// import {ICollateral} from "collateral/interfaces/ICollateral.sol";
import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";
import {SymPodStorageV1} from "src/symbiotic/SymPodStorageV1.sol";

contract SymPod is SymPodStorageV1 {
    error NotImplemented();

    /// @dev address used as ETH token
    address public constant ETH_ADDRESS = 0x0;

    constructor() {
        
    }

    /// @notice Create new validators
    /// @param pubkey validator public keys
    /// @param signature deposit validator signatures
    /// @param depositDataRoot deposit validator data roots
    function stake(
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot
    ) external payable override {
        bytes32 pubkeyHash = BeaconChainProofs.hashValidatorBLSPubkey(pubkey);

        /// Interaction
        ethDepositContract.deposit{value: msg.value}(
            pubkey,
            capsuleWithdrawalCredentials(), 
            signature,
            depositDataRoot
        );
        
        emit ObolPodStaked(pubkeyHash, msg.value);
    }


    function verifyValidatorWithdrawalCredentials() external {

    }

    /// @inheritdoc 
    function asset() external view returns (address) {
        return ETH_ADDRESS;
    }

    // function totalRepaidDebt() external view returns (uint256) {

    // }

    // function issuerRepaidDebt(address issuer) external view returns (uint256) {

    // }

    // function recipientRepaidDebt(address recipient) external view returns (uint256) {

    // }

    // function repaidDebt(address issuer, address recipient) external view returns (uint256) {

    // }

    // function totalDebt() external view returns (uint256) {

    // }

    // function issuerDebt(address issuer) external view returns (uint256) {

    // }


    // function recipientDebt(address recipient) external view returns (uint256) {

    // }

    // function debt(address issuer, address recipient) external view returns (uint256) {

    // }

    // function issueDebt(address recipient, uint256 amount) external {

    // }

    /// @inheritdoc SymPodStorageV1
    function withdraw(uint256, address, address) public pure override returns (uint256) {
        revert NotImplemented();
    }

    /// @inheritdoc SymPodStorageV1
    function redeem(uint256 shares, address to, address owner) public pure override returns (uint256 assets) {
        revert NotImplemented();
    }

    function previewDeposit(uint256 assets) public pure override returns (uint256 shares) {
        revert NotImplemented();
    }

    function previewRedeem(uint256 shares) public pure override returns (uint256 assets) {
        revert NotImplemented();
    }

}