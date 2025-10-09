// SPDX-License-Identifier: Proprietary
pragma solidity ^0.8.19;

import "forge-std/console.sol";
import {IDepositContract} from "../../../interfaces/IDepositContract.sol";

/// @title DepositContractMock
/// @notice This contract mocks the standard Deposit Contract.
contract DepositContractMock is IDepositContract {
  function deposit(bytes calldata, bytes calldata, bytes calldata, bytes32) external payable override {
    console.log("DepositContractMock.deposit called with value", msg.value);
  }

  function get_deposit_root() external pure override returns (bytes32) {
    revert("DepositContractMock.get_deposit_root not implemented");
  }

  function get_deposit_count() external pure override returns (bytes memory) {
    revert("DepositContractMock.get_deposit_count not implemented");
  }
}
