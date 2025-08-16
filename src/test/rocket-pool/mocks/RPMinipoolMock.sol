// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract RPMinipoolMock {
  using SafeTransferLib for address;

  function getEffectiveDelegate() external view returns (address) {
    return address(this);
  }

  function userDistributeAllowed() external pure returns (bool) {
    return true;
  }

  function distributeBalance(bool) external {
    if (address(this).balance > 0) msg.sender.safeTransferETH(address(this).balance);
  }

  receive() external payable {}
}
