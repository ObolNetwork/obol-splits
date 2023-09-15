// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IENSReverseRegistrar {
  function claim(address owner) external returns (bytes32);
  function defaultResolver() external view returns (address);
  function ens() external view returns (address);
  function node(address addr) external pure returns (bytes32);
  function setName(string memory name) external returns (bytes32);
}
