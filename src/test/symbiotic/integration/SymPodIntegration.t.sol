// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import "forge-std/Test.sol";

/**
 * Walks through a potential lifecycle of a SymPod
 */
contract SymPodIntegrationTest is Test {
  function setUp() public {}

  function test_VerifyWC_StartCP_CompleteCP_Withdraw() external {
    /**
     * -> Verify withdrawal credentials
     * -> Start Checkpoint
     * -> Complete Checkpoint
     * -> Withdraw
     * -> Verify WC
     * -> Start Checkpoint
     * -> Complete Withdraw
     */
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