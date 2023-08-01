// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract WaterfallTestHelper {

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
        returns (address[] memory recipients, uint256 threshold)
    {
        // MAX_TRANCHE_SIZE = 2
        recipients = generateTrancheRecipients(2, rSeed);
        threshold = generateTrancheThreshold(tSeed);
    }

    function generateTrancheRecipients(uint256 numRecipients, uint256 _seed)
        internal
        pure
        returns (address[] memory recipients)
    {
        recipients = new address[](numRecipients);
        bytes32 seed = bytes32(_seed);
        for (uint256 i = 0; i < numRecipients; i++) {
            seed = keccak256(abi.encodePacked(seed));
            recipients[i] = address(bytes20(seed));
        }
    }

    function generateTrancheThreshold(uint256 _seed)
        internal
        pure
        returns (uint256 threshold)
    {
        uint256 seed = _seed;
        seed = uint256(keccak256(abi.encodePacked(seed)));
        threshold = uint96(seed);
    }

}