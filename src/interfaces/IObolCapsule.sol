// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IObolCapsule {
    
    error InvalidAddress();
    error AlreadyInitialized();
    error InvalidStakeSize();

    
    event Initialized(address owner);
    event ObolPodStaked(bytes pubkey);


    function stake(
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot
    ) external payable;
}