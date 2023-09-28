// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

interface IEasyTrackMotion {

    /// @notice Creates new motion
    /// @param _evmScriptFactory Address of EVMScript factory registered in Easy Track
    /// @param _evmScriptCallData Encoded call data of EVMScript factory
    /// @return _newMotionId Id of created motion
    function createMotion(address _evmScriptFactory, bytes calldata _evmScriptCallData) external returns (uint256 _newMotionId);
}