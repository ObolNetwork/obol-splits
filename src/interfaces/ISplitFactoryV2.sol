// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

// The interface is the simplified version of the original contract (splits.org).
// The original contract uses greater solc version.
interface ISplitFactoryV2 {
  /**
   * @notice Split struct
   * @dev This struct is used to store the split information.
   * @dev There are no hard caps on the number of recipients/totalAllocation/allocation unit. Thus the chain and its
   * gas limits will dictate these hard caps. Please double check if the split you are creating can be distributed on
   * the chain.
   * @param recipients The recipients of the split.
   * @param allocations The allocations of the split.
   * @param totalAllocation The total allocation of the split.
   * @param distributionIncentive The incentive for distribution. Limits max incentive to 6.5%.
   */
  struct Split {
    address[] recipients;
    uint256[] allocations;
    uint256 totalAllocation;
    uint16 distributionIncentive;
  }

  /**
   * @notice Create a new split with params and owner.
   * @dev Uses a hash-based incrementing nonce over params and owner.
   * @dev designed to be used with integrating contracts to avoid salt management and needing to handle the potential
   * for griefing via front-running. See docs for more information.
   * @param _splitParams Params to create split with.
   * @param _owner Owner of created split.
   * @param _creator Creator of created split.
   */
  function createSplit(Split calldata _splitParams, address _owner, address _creator) external returns (address split);
}
