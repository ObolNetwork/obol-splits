// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import {BaseSymPodHarnessTest} from "../SymPod.t.sol";
import "forge-std/Test.sol";

contract SymPodIntegrationTest is BaseSymPodHarnessTest {
  function setUp() public override {
    super.setUp();

  }

  function testFuzz_VerifyWC_StartCP_CompleteCP_Withdraw(
    uint256 podBalance
  ) external {
    /**
     * -> Verify withdrawal credentials
     * -> Start Checkpoint
     * -> Complete Checkpoint
     * -> Withdraw
     * -> Verify WC
     * -> Start Checkpoint
     * -> Complete Withdraw
     * 
     * 
     * 
     * 
     * Look for exited validators and use the
     * slot prior to them
     */

    // createdHarnessPod.verifyValidatorWithdrawalCredentials({
    //   beaconTimestamp: 
    //   validatorRegistryProof:
    //   validatorProof: 
    // });
  }

  function test_VerifyWC_StartCP_CompleteCP_Withdraw_Slash() external {
    /**
     * -> Verify withdrawal credentials
     * -> Start Checkpoint
     * -> Complete Checkpoint
     * -> User gets slashed
     */
  }

  function test_StartCP_CompleteCP_Slash() external {
    
  }
}