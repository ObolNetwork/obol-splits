// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import {ObolEigenLayerPodController} from "./ObolEigenLayerPodController.sol";
import {LibClone} from "solady/utils/LibClone.sol";

/// @title ObolEigenLayerFactory
/// @author Obol
/// @notice A factory contract for cheaply deploying ObolLidoEigenLayer.
/// @dev The address returned should be used to as the EigenPod address
contract ObolEigenLayerPodControllerFactory {
    error Invalid_Owner();
    error Invalid_OWR();
    error Invalid_DelegationManager();
    error Invalid_EigenPodManaager();
    error Invalid_WithdrawalRouter();

    using LibClone for address;

    event CreatePodController(
        address indexed controller,
        address indexed owr,
        address owner
    );
    
    ObolEigenLayerPodController public immutable controllerImplementation;

    constructor(
        address feeRecipient,
        uint256 feeShare,
        address delegationManager,
        address eigenPodManager,
        address withdrawalRouter
    ) {
        if (delegationManager == address(0)) revert Invalid_DelegationManager();
        if (eigenPodManager == address(0)) revert Invalid_EigenPodManaager();
        if (withdrawalRouter == address(0)) revert Invalid_WithdrawalRouter();

        controllerImplementation = new ObolEigenLayerPodController(
            feeRecipient,
            feeShare,
            delegationManager,
            eigenPodManager,
            withdrawalRouter
        );
        // initialize implementation
        controllerImplementation.initialize(
            feeRecipient,
            feeRecipient
        );
    }

    /// Creates a minimal proxy clone of implementation
    /// @param owner address of owner
    /// @param owr address of owr
    /// @return controller Deployed obol eigen layer controller
    function createPodController(address owner, address owr)
        external
        returns (address controller) 
    {
        if (owner == address(0)) revert Invalid_Owner();
        if (owr == address(0)) revert Invalid_OWR();

        bytes32 salt = _createSalt(
            owner, owr
        );

        controller = address(controllerImplementation).cloneDeterministic("", salt);

        ObolEigenLayerPodController(controller).initialize(
            owner,
            owr
        );

        emit CreatePodController(
            controller,
            owr,
            owner
        );
    }


    function predictControllerAddress(
        address owner,
        address owr
    ) external view returns (address controller) {
        bytes32 salt = _createSalt(owner, owr);
        controller = address(controllerImplementation).predictDeterministicAddress(
            "",
            salt,
            address(this)
        );
    }

    function _createSalt(
        address owner,
        address owr
    ) internal pure returns (bytes32 salt) {
        return keccak256(
            abi.encode(owner, owr)
        );
    }

}