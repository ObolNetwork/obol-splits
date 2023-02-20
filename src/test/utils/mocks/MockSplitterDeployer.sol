// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import {ObolSplitterDeployer, ISplitMain} from "../../../Splitter.sol";

contract MockSplitterDeployer is ObolSplitterDeployer {
  constructor(ISplitMain splitterContract, address obolWallet)
    ObolSplitterDeployer(splitterContract, obolWallet)
  {}
}
