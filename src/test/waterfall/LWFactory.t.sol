// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {AddressBook} from "./LW1155.t.sol";
import {LWFactory} from "../../waterfall/LWFactory.sol";
import {IENSReverseRegistrar} from "../../interfaces/IENSReverseRegistrar.sol";
import {ISplitMain, SplitConfiguration} from "../../interfaces/ISplitMain.sol";
import {IWaterfallModule} from "../../interfaces/IWaterfallModule.sol";

contract LWFactoryTest is Test, AddressBook {
  LWFactory lwFactory;

  function setUp() public {
    uint256 goerliBlock = 8_529_931;

    vm.createSelectFork(getChain("goerli").rpcUrl, goerliBlock);
    // for local tests, mock the ENS reverse registrar at its goerli address.
    vm.mockCall(
      ensReverseRegistrar, abi.encodeWithSelector(IENSReverseRegistrar.setName.selector), bytes.concat(bytes32(0))
    );
    vm.mockCall(
      ensReverseRegistrar, abi.encodeWithSelector(IENSReverseRegistrar.claim.selector), bytes.concat(bytes32(0))
    );

    lwFactory = new LWFactory(
            WATERFALL_FACTORY_MODULE_GOERLI,
            SPLIT_MAIN_GOERLI,
            "demo.obol.eth",
            ensReverseRegistrar,
            address(this)
        );
  }

  function testCreateETHRewardSplit() external {
    address[] memory accounts = new address[](2);
    accounts[0] = address(lwFactory.lw1155());
    accounts[1] = makeAddr("accounts1");

    uint32[] memory percentAllocations = new uint32[](2);
    percentAllocations[0] = 400_000;
    percentAllocations[1] = 600_000;

    SplitConfiguration memory splitConfig = SplitConfiguration(accounts, percentAllocations, 0, address(0x0));

    address payable principal = payable(makeAddr("accounts2"));
    uint256 numberOfValidators = 10;

    (address[] memory withdrawAddresses, address splitRecipient) =
      lwFactory.createETHRewardSplit(splitConfig, principal, numberOfValidators);

    // confirm expected splitrecipient address
    address expectedSplitRecipient =
      ISplitMain(SPLIT_MAIN_GOERLI).predictImmutableSplitAddress(accounts, percentAllocations, 0);
    assertEq(splitRecipient, expectedSplitRecipient, "invalid split configuration");

    address[] memory expectedRecipients = new address[](2);
    expectedRecipients[0] = address(lwFactory.lw1155());
    expectedRecipients[1] = splitRecipient;

    uint256[] memory expectedThresholds = new uint256[](1);
    expectedThresholds[0] = 32 ether;

    for (uint256 i = 0; i < withdrawAddresses.length; i++) {
      (address[] memory recipients, uint256[] memory thresholds) = IWaterfallModule(withdrawAddresses[i]).getTranches();

      assertEq(recipients, expectedRecipients, "invalid recipients");
      assertEq(thresholds, expectedThresholds, "invalid thresholds");
    }
  }
}
