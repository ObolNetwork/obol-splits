// SPDX-License-Identifier: NONE
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "./Utils.s.sol";
import {ObolValidatorManager} from "src/ovm/ObolValidatorManager.sol";
import {IObolValidatorManager} from "src/interfaces/IObolValidatorManager.sol";

//
// This script calls consolidate() for an ObolValidatorManager contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
//
contract ConsolidateScript is Script {
  function run(
    address ovmAddress,
    bytes calldata src,
    bytes calldata dst,
    uint256 maxFeePerConsolidation,
    address excessFeeRecipient
  ) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    if (privKey == 0) revert("set PRIVATE_KEY env var before using this script");
    if (!Utils.isContract(ovmAddress)) revert("Invalid OVM address");
    if (src.length != 48) revert("Invalid source pubkey length, must be 48 bytes");
    if (dst.length != 48) revert("Invalid destination pubkey length, must be 48 bytes");
    if (maxFeePerConsolidation == 0) revert("Invalid max fee per consolidation");
    if (excessFeeRecipient == address(0)) revert("Invalid excess fee recipient address");

    vm.startBroadcast(privKey);

    ObolValidatorManager ovm = ObolValidatorManager(payable(ovmAddress));

    console.log("OVM address:", ovmAddress);
    console.log("Source pubkey (first 20 bytes):");
    console.logBytes(src[:20]);
    console.log("Destination pubkey (first 20 bytes):");
    console.logBytes(dst[:20]);
    console.log("Max fee per consolidation: %d wei", maxFeePerConsolidation);
    console.log("Excess fee recipient: %s", excessFeeRecipient);

    bytes[] memory sourcePubKeys = new bytes[](1);
    sourcePubKeys[0] = src;

    IObolValidatorManager.ConsolidationRequest[] memory requests = new IObolValidatorManager.ConsolidationRequest[](1);
    requests[0] = IObolValidatorManager.ConsolidationRequest({srcPubKeys: sourcePubKeys, targetPubKey: dst});

    ovm.consolidate{value: maxFeePerConsolidation}(requests, maxFeePerConsolidation, excessFeeRecipient);

    console.log("Consolidation request submitted successfully");

    vm.stopBroadcast();
  }
}
