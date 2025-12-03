// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRocketPoolMinipoolManager {
  function getMinipoolExists(address _minipoolAddress) external view returns (bool);
  function getMinipoolByPubkey(bytes memory _pubkey) external view returns (address);
  function getMinipoolWithdrawalCredentials(address _minipoolAddress) external pure returns (bytes memory);
  function getVacantMinipoolCount() external view returns (uint256);
  function getVacantMinipoolAt(uint256 _index) external view returns (address);
  function setMinipoolPubkey(bytes calldata _pubkey) external;
}
