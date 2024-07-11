// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRocketPoolStorage {
    function getAddress(bytes32 _key) external view returns (address r);
    function getUint(bytes32 _key) external view returns (uint256 r);
    function getString(bytes32 _key) external view returns (string memory);
    function getBytes(bytes32 _key) external view returns (bytes memory);
    function getBool(bytes32 _key) external view returns (bool r);
    function getInt(bytes32 _key) external view returns (int r);
    function getBytes32(bytes32 _key) external view returns (bytes32 r);
}