// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// address internal constant RP_DEPOSIT = 0xDD3f50F8A6CafbE9b31a427582963f465E745AF8;
// address internal constant RP_STORAGE = 0x1d8f8f00cfa6758d7bE78336684788Fb0ee0Fa46;
interface IRocketPoolStorage {
  function getAddress(bytes32 _key) external view returns (address r);
  function getUint(bytes32 _key) external view returns (uint256 r);
  function getString(bytes32 _key) external view returns (string memory);
  function getBytes(bytes32 _key) external view returns (bytes memory);
  function getBool(bytes32 _key) external view returns (bool r);
  function getInt(bytes32 _key) external view returns (int256 r);
  function getBytes32(bytes32 _key) external view returns (bytes32 r);
}
