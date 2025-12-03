// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

contract RPMinipoolManagerMock {
  function getMinipoolExists(address) external pure returns (bool) {
    return true;
  }
}
