// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;     

import {Ownable} from "solady/auth/Ownable.sol";

//https://docs.rocketpool.net/overview/contracts-integrations
contract ObolRocketPoolStorage is Ownable {
    // address internal constant RP_DEPOSIT = 0xDD3f50F8A6CafbE9b31a427582963f465E745AF8;
    // address internal constant RP_STORAGE = 0x1d8f8f00cfa6758d7bE78336684788Fb0ee0Fa46;
    //TODO: add rEth
    /// -----------------------------------------------------------------------
    /// storage - mutables
    /// -----------------------------------------------------------------------
    address public rocketPoolStorage;
    address public rocketPoolDeposit;
    address public rocketPoolMinipoolManager;
    address public rEth;

    /// -----------------------------------------------------------------------
    /// errors
    /// -----------------------------------------------------------------------
    /// Invalid address
    error InvalidAddress();

    /// -----------------------------------------------------------------------
    /// events
    /// -----------------------------------------------------------------------
    event RocketPoolStorageAddressUpdated(address indexed oldVal, address indexed newVal);
    event RocketPoolDepositAddressUpdated(address indexed oldVal, address indexed newVal);
    event RocketPoolMiniPoolManagerAddressUpdated(address indexed oldVal, address indexed newVal);
    event RocketPoolREthAddressUpdated(address indexed oldVal, address indexed newVal);

    /// -----------------------------------------------------------------------
    /// functions
    /// -----------------------------------------------------------------------
    
    /// -----------------------------------------------------------------------
    /// functions - owner
    /// -----------------------------------------------------------------------
    /// @notice sets the RocketPool storage address
    /// @param _storage the new address
    function setPoolStorage(address _storage) external onlyOwner {
        if (_storage == address(0)) revert InvalidAddress();

        emit RocketPoolStorageAddressUpdated(rocketPoolStorage, _storage);
        rocketPoolStorage = _storage;
    }

    /// @notice sets the RocketPool deposit address
    /// @param _deposit the new address
    function setPoolDeposit(address _deposit) external onlyOwner {
        if (_deposit == address(0)) revert InvalidAddress();

        emit RocketPoolDepositAddressUpdated(rocketPoolDeposit, _deposit);
        rocketPoolDeposit = _deposit;
    }

    /// @notice sets the RocketPool minipool manager address
    /// @param _manager the new address
    function setMinipoolManager(address _manager) external onlyOwner {
        if (_manager == address(0)) revert InvalidAddress();

        emit RocketPoolMiniPoolManagerAddressUpdated(rocketPoolMinipoolManager, _manager);
        rocketPoolMinipoolManager = _manager;
    }

    /// @notice sets the RocketPool RETH token address
    /// @param _rEth the new address
    function setREth(address _rEth) external onlyOwner {
        if (_rEth == address(0)) revert InvalidAddress();

        emit RocketPoolREthAddressUpdated(rEth, _rEth);
        rEth = _rEth;
    }
}