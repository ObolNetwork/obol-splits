// SPDX-License-Identifier: NONE
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "./Utils.s.sol";
import {ObolValidatorManager} from "src/ovm/ObolValidatorManager.sol";

//
// This script calls withdraw() for an ObolValidatorManager contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
//
contract WithdrawScript is Script {
  function run(
    address ovmAddress,
    bytes calldata pubkey,
    uint64 amount,
    uint256 maxFeePerWithdrawal,
    address excessFeeRecipient
  ) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    if (privKey == 0) revert("set PRIVATE_KEY env var before using this script");
    if (!Utils.isContract(ovmAddress)) revert("Invalid OVM address");
    if (amount == 0) revert("Invalid withdrawal amount");
    if (pubkey.length != 48) revert("Invalid pubkey length, must be 48 bytes");
    if (maxFeePerWithdrawal == 0) revert("Invalid max fee per withdrawal");
    if (excessFeeRecipient == address(0)) revert("Invalid excess fee recipient address");

    vm.startBroadcast(privKey);

    ObolValidatorManager ovm = ObolValidatorManager(payable(ovmAddress));

    console.log("OVM address:", ovmAddress);
    console.log("Withdrawing for pubkey (first 20 bytes):");
    console.logBytes(pubkey[:20]);
    console.log("Amount to withdraw: %d gwei", amount);
    console.log("Max fee per withdrawal: %d wei", maxFeePerWithdrawal);
    console.log("Excess fee recipient: %s", excessFeeRecipient);

    bytes[] memory pubKeys = new bytes[](1);
    pubKeys[0] = pubkey;

    uint64[] memory amounts = new uint64[](1);
    amounts[0] = amount;

    ovm.withdraw{value: maxFeePerWithdrawal}(pubKeys, amounts, maxFeePerWithdrawal, excessFeeRecipient);

    console.log("Withdrawal request submitted successfully");

    vm.stopBroadcast();
  }
}
