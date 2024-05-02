// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IObolCapsule {
    
    error InvalidAddress();
    error AlreadyInitialized();
    error InvalidStakeSize();
    error InvalidProof();
    error InvalidCallData();
    error Invalid_FeeShare(uint256 fee);
    error Invalid_FeeRecipient();
    error Invalid_Timestamp(uint256 timestamp);
    
    event Initialized(address owner);
    event ObolPodStaked(bytes pubkey);


    function stake(
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot
    ) external payable;
}