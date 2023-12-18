// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {
    IEigenLayerUtils,
    IEigenPodManager,
    IDelayedWithdrawalRouter
} from "../interfaces/IEigenLayer.sol";


/// @title ObolEigenLayerFactory
/// @author Obol
/// @notice A factory contract for cheaply deploying ObolLidoEigenLayer.
/// @dev The address returned should be used to as reward address for Lido
contract ObolEigenLayerPodController {

    /// @dev returned on failed call
    error CallFailed(bytes data);
    /// @dev If Invalid fee setup
    error Invalid_FeeSetup();
    /// @dev user unauthorized
    error Unauthorized();
    /// @dev contract already initialized
    error AlreadyInitialized();

    /// @dev Emiited on intialize
    event Initialized(address eigenPod, address owner);
    
    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------
    using SafeTransferLib for address;
    using SafeTransferLib for ERC20;

    uint256 internal constant PERCENTAGE_SCALE = 1e5;

    /// -----------------------------------------------------------------------
    /// storage - immutables
    /// -----------------------------------------------------------------------

    /// @notice address of Eigenlayer delegation manager
    /// @dev This is the address of the delegation manager transparent proxy 
    address public immutable eigenLayerDelegationManager;

    /// @notice address of EigenLayerPod Manager
    /// @dev this is the pod manager transparent proxy
    IEigenPodManager public immutable eigenLayerPodManager;

    /// @notice address of delay withdrawal router
    IDelayedWithdrawalRouter public immutable delayedWithdrawalRouter;

    /// @notice fee address
    address public immutable feeRecipient;

    /// @notice fee share
    uint256 public immutable feeShare;

    /// -----------------------------------------------------------------------
    /// storage
    /// -----------------------------------------------------------------------

    /// @notice address of deployed Eigen pod
    address public eigenPod;

    /// @notice address of a splitter
    address public split;

    /// @notice address of owner
    address public owner;


    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert Unauthorized();
        }
        _;
    }

    constructor(
        address recipient,
        uint256 share,
        address delegationManager,
        address eigenPodManager,
        address withdrawalRouter
    ) {
        if (recipient != address(0) && share == 0) revert Invalid_FeeSetup();

        feeRecipient = recipient;
        feeShare = share;
        eigenLayerDelegationManager = delegationManager;
        eigenLayerPodManager = IEigenPodManager(eigenPodManager);
        delayedWithdrawalRouter = IDelayedWithdrawalRouter(withdrawalRouter);
    }

    /// @dev Enables contract to receive ETH
    // defined on the clone implementation
    // receive() external payable {}

    /// @notice initializes the controller
    /// @param _owner address of the controller owner
    /// @param splitter address of splitter
    function initialize(address _owner, address splitter) external {
        if (owner != address(0)) revert AlreadyInitialized();

        eigenPod = eigenLayerPodManager.createPod();
        owner = _owner;
        split = splitter;

        emit Initialized(eigenPod, _owner);
    }

    /// @notice Call the eigenPod contract
    /// @param data to call eigenPod contract
    function callEigenPod( 
        bytes calldata data
    ) external payable onlyOwner {
        _executeCall(address(eigenPod), msg.value, data);
    }

    /// @notice Call the Eigenlayer delegation Manager contract
    /// @param data to call eigenPod contract
    function callDelegationManager(
        bytes calldata data
    ) external payable onlyOwner {
        _executeCall(address(eigenLayerDelegationManager), msg.value, data);
    }

    /// @notice Call the Eigenlayer Manager contract
    /// @param data to call contract
    function callEigenPodManager(
        bytes calldata data
    ) external payable onlyOwner {
        _executeCall(address(eigenLayerPodManager), msg.value, data);
    }

    /// @notice Withdraw funds from the delayed withdrawal router
    /// @param numberOfDelayedWithdrawalsToClaim number of claims
    function claimDelayedWithdrawals(uint256 numberOfDelayedWithdrawalsToClaim)
        external
    {
        delayedWithdrawalRouter.claimDelayedWithdrawals(
            address(this),
            numberOfDelayedWithdrawalsToClaim
        );

        // transfer eth to split
        uint256 balance = address(this).balance;
        if (feeShare > 0) {
            uint256 fee =  (balance * feeShare) / PERCENTAGE_SCALE;
            feeRecipient.safeTransferETH(fee);
            split.safeTransferETH(balance -= fee);
        } else {
            split.safeTransferETH(address(this).balance);
        }
    }

    /// @notice Rescue stuck tokens
    /// @param token address of token
    /// @param amount amount of token to rescue
    function rescueFunds(address token, uint256 amount) external {
        if (amount > 0) ERC20(token).safeTransfer(split, amount);
    }

    /// @notice Execute a low level call
    /// @param to address to execute call
    /// @param value amount of ETH to send with call
    /// @param data bytes array to execute
    function _executeCall(address to, uint256 value, bytes memory data) internal {
        (bool success,) = address(to).call{value: value}(data);
        if (!success) revert CallFailed(data);
    }

}