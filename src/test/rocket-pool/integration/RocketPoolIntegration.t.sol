// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {ObolRocketPoolRecipientFactory} from "src/rocket-pool/ObolRocketPoolRecipientFactory.sol";
import {ObolRocketPoolRecipient} from "src/rocket-pool/ObolRocketPoolRecipient.sol";
import {RocketPoolTestHelper} from "../RocketPoolTestHelper.t.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IENSReverseRegistrar} from "../../../interfaces/IENSReverseRegistrar.sol";
import {IRocketPoolMinipoolManager} from "src/interfaces/external/rocketPool/IRocketPoolMinipoolManager.sol";
import {IRocketMinipoolDelegate} from "src/interfaces/external/rocketPool/IRocketMinipoolDelegate.sol";
import {IRocketMinipoolBase} from "src/interfaces/external/rocketPool/IRocketMinipoolBase.sol";
import {IRocketPoolStorage} from "src/interfaces/external/rocketPool/IRocketPoolStorage.sol";

contract RocketPoolIntegrationTest is RocketPoolTestHelper, Test {
  using SafeTransferLib for address;

  ObolRocketPoolRecipient public rpModule;
  ObolRocketPoolRecipientFactory public rpFactory;
  address internal recoveryAddress;

  ObolRocketPoolRecipient public rpRecipient;

  address public principalRecipient;
  address public rewardRecipient;
  uint256 internal trancheThreshold;

  address public constant MINIPOOL_MANAGER = 0x09fbCE43e4021a3F69C4599FF00362b83edA501E;
  address public constant MINIPOOL = 0x5cF493b240f27D1d55038C9b5CAebB0E0849519E;
  address public constant MINIPOOL_WITHDRAWAL_ADDRESS = 0x38ed4462C9F4CD13B03E355a33Ef8AE6B65E53D4;
  address public ENS_REVERSE_REGISTRAR_MAINNET = 0xa58E81fe9b61B5c3fE2AFD33CF304c454AbFc7Cb;
  address public constant RP_STORAGE = 0x1d8f8f00cfa6758d7bE78336684788Fb0ee0Fa46;

  function setUp() public {
    uint256 rpcBlock = 20_382_513;
    vm.createSelectFork(getChain("mainnet").rpcUrl, rpcBlock);

    vm.mockCall(
      ENS_REVERSE_REGISTRAR_MAINNET,
      abi.encodeWithSelector(IENSReverseRegistrar.setName.selector),
      bytes.concat(bytes32(0))
    );
    vm.mockCall(
      ENS_REVERSE_REGISTRAR_MAINNET,
      abi.encodeWithSelector(IENSReverseRegistrar.claim.selector),
      bytes.concat(bytes32(0))
    );

    rpFactory =
      new ObolRocketPoolRecipientFactory(RP_STORAGE, "demo.obol.eth", ENS_REVERSE_REGISTRAR_MAINNET, address(this));

    rpModule = rpFactory.rpRecipientImplementation();

    (principalRecipient, rewardRecipient) = generateTrancheRecipients(uint256(uint160(makeAddr("tranche"))));
    // use 1 validator as default tranche threshold
    trancheThreshold = ETH_STAKE;

    recoveryAddress = makeAddr("recoveryAddress");

    rpRecipient =
      rpFactory.createObolRocketPoolRecipient(recoveryAddress, principalRecipient, rewardRecipient, trancheThreshold);
  }

  function testRocketPoolRecipientViewInteractions() public {
    // simulate calls from RocketPoolRecipient
    vm.startPrank(address(rpRecipient));
    address _manager = IRocketPoolStorage(RP_STORAGE).getAddress(
      keccak256(abi.encodePacked("contract.address", "rocketMinipoolManager"))
    );
    bool _poolExists = IRocketPoolMinipoolManager(_manager).getMinipoolExists(MINIPOOL);
    // test delegate
    bool _distributionAllowed = IRocketMinipoolDelegate(MINIPOOL).userDistributeAllowed();
    vm.stopPrank();

    assertEq(_manager, MINIPOOL_MANAGER);
    assertTrue(_poolExists);
    assertFalse(_distributionAllowed);
  }

  function testRocketPoolRecipientDistributeInteraction() public {
    skip(86_400 * 50);

    uint256 _withdrawalAddressBalance = MINIPOOL_WITHDRAWAL_ADDRESS.balance;

    // simulate withdrawal address calling the minipool
    // this would be the RocketPoolRecipient contract in our case
    vm.startPrank(MINIPOOL_WITHDRAWAL_ADDRESS);
    IRocketMinipoolDelegate(MINIPOOL).distributeBalance(true);

    assertGt(MINIPOOL_WITHDRAWAL_ADDRESS.balance, _withdrawalAddressBalance);

    console.log(MINIPOOL_WITHDRAWAL_ADDRESS.balance - _withdrawalAddressBalance);
  }
  // to make sure the contract was set-up properly

  function testGetTranches_rp_integration() public {
    (address _principalRecipient, address _rewardRecipient, uint256 wtrancheThreshold) = rpRecipient.getTranches();

    assertEq(_principalRecipient, principalRecipient, "invalid principal recipient");
    assertEq(_rewardRecipient, rewardRecipient, "invalid reward recipient");
    assertEq(wtrancheThreshold, ETH_STAKE, "invalid eth tranche threshold");
  }
}
