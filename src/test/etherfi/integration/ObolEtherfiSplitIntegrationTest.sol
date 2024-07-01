// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ObolEtherfiSplitFactory, ObolEtherfiSplit} from "src/etherfi/ObolEtherfiSplitFactory.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ObolEtherfiSplitTestHelper} from "../ObolEtherfiSplitTestHelper.sol";
import {ISplitMain} from "src/interfaces/external/splits/ISplitMain.sol";

contract ObolEtherfiSplitIntegrationTest is ObolEtherfiSplitTestHelper, Test {
  ObolEtherfiSplitFactory internal etherfiSplitFactory;
  ObolEtherfiSplit internal etherfiSplit;

  address splitter;

  address[] accounts;
  uint32[] percentAllocations;

  address internal SPLIT_MAIN_MAINNET = 0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE;

  function setUp() public {
    uint256 mainnetBlock = 19_228_949;
    vm.createSelectFork(getChain("mainnet").rpcUrl, mainnetBlock);

    etherfiSplitFactory =
      new ObolEtherfiSplitFactory(address(0), 0, ERC20(EETH_MAINNET_ADDRESS), ERC20(WEETH_MAINNET_ADDRESS));

    accounts = new address[](2);
    accounts[0] = makeAddr("accounts0");
    accounts[1] = makeAddr("accounts1");

    percentAllocations = new uint32[](2);
    percentAllocations[0] = 400_000;
    percentAllocations[1] = 600_000;

    splitter = ISplitMain(SPLIT_MAIN_MAINNET).createSplit(accounts, percentAllocations, 0, address(0));

    etherfiSplit = ObolEtherfiSplit(etherfiSplitFactory.createCollector(address(0), splitter));
  }

  function test_etherfi_integration_CanDistribute() public {
    vm.prank(RANDOM_EETH_ACCOUNT_ADDRESS);
    ERC20(EETH_MAINNET_ADDRESS).transfer(address(etherfiSplit), 100 ether);

    etherfiSplit.distribute();

    ISplitMain(SPLIT_MAIN_MAINNET).distributeERC20(
      splitter, ERC20(WEETH_MAINNET_ADDRESS), accounts, percentAllocations, 0, address(0)
    );

    ERC20[] memory tokens = new ERC20[](1);
    tokens[0] = ERC20(WEETH_MAINNET_ADDRESS);

    ISplitMain(SPLIT_MAIN_MAINNET).withdraw(accounts[0], 0, tokens);
    ISplitMain(SPLIT_MAIN_MAINNET).withdraw(accounts[1], 0, tokens);

    assertEq(
      ERC20(WEETH_MAINNET_ADDRESS).balanceOf(accounts[0]), 38_787_430_925_418_583_374, "invalid account 0 balance"
    );
    assertEq(
      ERC20(WEETH_MAINNET_ADDRESS).balanceOf(accounts[1]), 58_181_146_388_127_875_061, "invalid account 1 balance"
    );
  }
}
