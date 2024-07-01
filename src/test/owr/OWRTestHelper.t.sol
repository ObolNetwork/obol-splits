// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

contract OWRTestHelper {
  address internal constant ETH_ADDRESS = address(0);

  uint256 internal constant MAX_TRANCHE_SIZE = 2;

  uint256 internal constant ETH_STAKE = 32 ether;

  uint256 internal constant BALANCE_CLASSIFICATION_THRESHOLD = 16 ether;

  /// -----------------------------------------------------------------------
  /// helper fns
  /// -----------------------------------------------------------------------

  function generateTranches(uint256 rSeed, uint256 tSeed)
    internal
    pure
    returns (address principal, address reward, uint256 threshold)
  {
    (principal, reward) = generateTrancheRecipients(rSeed);
    threshold = generateTrancheThreshold(tSeed);
  }

  function generateTrancheRecipients(uint256 _seed) internal pure returns (address principal, address reward) {
    bytes32 seed = bytes32(_seed);

    seed = keccak256(abi.encodePacked(seed));
    principal = address(bytes20(seed));

    seed = keccak256(abi.encodePacked(seed));
    reward = address(bytes20(seed));
  }

  function generateTrancheThreshold(uint256 _seed) internal pure returns (uint256 threshold) {
    uint256 seed = _seed;
    seed = uint256(keccak256(abi.encodePacked(seed)));
    threshold = uint96(seed);
  }
}
