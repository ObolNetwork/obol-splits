// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IBeaconRootsContract {
    function get(bytes calldata timestamp) external view returns (bytes32);
}