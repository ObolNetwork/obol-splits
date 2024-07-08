// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import {stdJson} from "forge-std/Test.sol";
import { StateProofVerifierV1 } from "src/verifiers/StateProofVerifierV1.sol";
import {BeaconChainProofs} from "src/libraries/BeaconChainProof.sol";

contract StateProofVerifierHarnessV1 is StateProofVerifierV1 {

    // function verifyWithdrawalWithBeaconStateRoot(
    //     // bytes32 beaconStateRoot,
    //     // BeaconChainProofs.WithdrawalProof memory withdrawalProof,
    //     // bytes memory validatorFieldsProof,
    //     // bytes32[] memory validatorFields,
    //     // bytes32[] memory withdrawalFields
    // ) public view returns (Withdrawal memory withdrawal) {
    //     return _verifyWithdrawal(
    //         beaconStateRoot,
    //         withdrawalProof,
    //         validatorFieldsProof,
    //         validatorFields,
    //         withdrawalFields
    //     );
    // }
    
}