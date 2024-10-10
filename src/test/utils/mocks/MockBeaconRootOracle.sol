// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;
import "forge-std/Test.sol";

contract MockBeaconRootOracle is Test {

    mapping(uint => bytes32) beaconBlockRoots;

    uint constant HISTORY_BUFFER_LENGTH = 8191;

    fallback() external {
        require(msg.data.length == 32, "MockEIP4788Oracle.fallback: malformed msg.data");

        uint timestamp = abi.decode(msg.data, (uint));
        require(timestamp != 0, "MockEIP4788Oracle.fallback: timestamp is 0");

        bytes32 blockRoot = beaconBlockRoots[timestamp];
        require(blockRoot != 0, "MockEIP4788Oracle.fallback: no block root found. DID YOU USE CHEATS.WARP?");

        assembly {
            mstore(0, blockRoot)
            return(0, 32)
        }
    }

    function timestampToBlockRoot(uint timestamp) public view returns (bytes32) {
        return beaconBlockRoots[uint64(timestamp)];
    }

    function setBlockRoot(uint64 timestamp, bytes32 blockRoot) public {
        beaconBlockRoots[timestamp] = blockRoot;
    }
}