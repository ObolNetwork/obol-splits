// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {MockERC20} from "src/test/utils/mocks/MockERC20.sol";
import {ObolStakewiseSplitFactory} from "src/stakewise/ObolStakewiseSplitFactory.sol";

contract ObolStakewiseSplitFactoryTest is Test {
  ObolStakewiseSplitFactory internal stakewiseSplitFactory;
  ObolStakewiseSplitFactory internal stakewiseSplitFactoryWithFee;

  MockERC20 internal vaultToken;

  address feeRecipient;
  uint256 feeShare;
  address demoSplit;

  event CreateObolStakewiseSplit(address split);

  function setUp() public {
    uint256 mainnetBlock = 19_167_592;
    vm.createSelectFork(getChain("mainnet").rpcUrl, mainnetBlock);

    feeShare = 1e4; //10%
    demoSplit = makeAddr("StakewiseDemoSplit");
    feeRecipient = makeAddr("StakewiseFeeRecipient");

    vaultToken = new MockERC20("Test", "TST", uint8(18));

    stakewiseSplitFactory = new ObolStakewiseSplitFactory(address(0), 0, ERC20(vaultToken));

    stakewiseSplitFactoryWithFee = new ObolStakewiseSplitFactory(feeRecipient, feeShare, ERC20(vaultToken));
  }

  function test_stakewise_canCreateSplit() public {
    vm.expectEmit(true, true, true, false, address(stakewiseSplitFactory));
    emit CreateObolStakewiseSplit(address(0x1));

    stakewiseSplitFactory.createSplit(demoSplit);

    vm.expectEmit(true, true, true, false, address(stakewiseSplitFactoryWithFee));
    emit CreateObolStakewiseSplit(address(0x1));

    stakewiseSplitFactoryWithFee.createSplit(demoSplit);
  }

  function test_stakewise_cannotCreateSplitInvalidAddress() public {
    vm.expectRevert(ObolStakewiseSplitFactory.Invalid_Wallet.selector);
    stakewiseSplitFactory.createSplit(address(0));

    vm.expectRevert(ObolStakewiseSplitFactory.Invalid_Wallet.selector);
    stakewiseSplitFactoryWithFee.createSplit(address(0));
  }
}
