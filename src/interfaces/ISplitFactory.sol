// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ISplitMainV2} from "./ISplitMainV2.sol";

interface ISplitFactory {
  function splitMain() external view returns (ISplitMainV2);

  function createSplit(
    bytes32 splitWalletId,
    address[] calldata accounts,
    uint32[] calldata percentAllocations,
    uint32 distributorFee,
    address distributor,
    address controller
  ) external returns (address);

  function predictImmutableSplitAddress(
    bytes32 splitWalletId,
    address[] calldata accounts,
    uint32[] calldata percentAllocations,
    uint32 distributorFee
  ) external returns (address);
}
