// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {ERC1155} from "solmate/tokens/ERC1155.sol";
import "src/waterfall/token/LW1155.sol";
import {utils} from "../../lib/Utils.sol";
import {ISplitMain, SplitConfiguration} from "../../interfaces/ISplitMain.sol";
import {IWaterfallModule} from "../../interfaces/IWaterfallModule.sol";
import {IWaterfallFactoryModule} from "../../interfaces/IWaterfallFactoryModule.sol";
import {MockERC20} from "../utils/mocks/MockERC20.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";


contract AddressBook {
  address public ensReverseRegistrar = 0x084b1c3C81545d370f3634392De611CaaBFf8148;
  uint256 internal constant ETH_STAKE = 32 ether;
  address internal WATERFALL_FACTORY_MODULE_GOERLI = 0xd647B9bE093Ec237be72bB17f54b0C5Ada886A25;
  address internal SPLIT_MAIN_GOERLI = 0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE;
}

contract BaseTest is AddressBook, Test {
  LW1155 public lw1155;

  address user1;
  address user2;

  address rewardSplit;
  address waterfallModule;
  address obolTreasury;
  SplitConfiguration configuration;
  MockERC20 mockERC20;

  error Unauthorized();
  error InvalidOwner();

  event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 amount);

  function setUp() public {
    uint256 goerliBlock = 8_529_931;

    vm.createSelectFork(getChain("goerli").rpcUrl, goerliBlock);

    user1 = makeAddr("1");
    user2 = makeAddr("2");
    obolTreasury = makeAddr("3");
    lw1155 = new LW1155(ISplitMain(SPLIT_MAIN_GOERLI), obolTreasury);

    mockERC20 = new MockERC20("demo", "DMT", 18);

    uint32[] memory percentAllocations = new uint32[](2);
    percentAllocations[0] = 500_000;
    percentAllocations[1] = 500_000;

    address[] memory accounts = new address[](2);
    accounts[0] = address(lw1155);
    accounts[1] = user2;

    configuration = SplitConfiguration(accounts, percentAllocations, 0, address(0));

    rewardSplit = ISplitMain(SPLIT_MAIN_GOERLI).createSplit(accounts, percentAllocations, 0, address(0));

    address[] memory waterfallRecipients = new address[](2);
    waterfallRecipients[0] = address(lw1155);
    waterfallRecipients[1] = address(rewardSplit);

    uint256[] memory thresholds = new uint256[](1);
    thresholds[0] = ETH_STAKE;

    waterfallModule = IWaterfallFactoryModule(WATERFALL_FACTORY_MODULE_GOERLI).createWaterfallModule(
      address(0), address(0), waterfallRecipients, thresholds
    );
  }
}

contract LW1155OwnerTest is BaseTest {
  function testOwner() public {
    assertEq(lw1155.owner(), address(this));
  }
}

contract LW1155UriTest is BaseTest {
  function testCanFetchUri() public {
    vm.expectCall(address(lw1155), abi.encodeCall(lw1155.uri, (0)));
    lw1155.uri(0);
  }
}

contract LW1155NameTest is BaseTest {
  function testCanFetchName() public {
    assertEq(lw1155.name(), string.concat("Obol Liquid Waterfall Split ", utils.shortAddressToString(address(lw1155))));
  }
}

contract LW1155MintTest is BaseTest {
  function testOnlyOwnerCanMint() public {
    vm.prank(user1);
    vm.expectRevert(Unauthorized.selector);

    lw1155.mint(user1, rewardSplit, waterfallModule, configuration);
  }

  function testCanMint() public {
    uint256 id = uint256(keccak256(abi.encodePacked(user1, waterfallModule)));
    vm.expectEmit(true, true, true, true, address(lw1155));
    emit TransferSingle(address(this), address(0), user1, id, 1);

    lw1155.mint(user1, rewardSplit, waterfallModule, configuration);

    // assert claim information
    (ISplitMain receivedRewardSplit, IWaterfallModule receivedWaterfallModule, SplitConfiguration memory receivedConfig)
    = lw1155.claimData(id);
    assertEq(address(receivedRewardSplit), rewardSplit);
    assertEq(address(receivedWaterfallModule), waterfallModule);
    assertEq(configuration.accounts, receivedConfig.accounts);
    // assertEq(configuration.percentAllocations, receivedConfig.percentAllocations);
    assertEq(configuration.distributorFee, receivedConfig.distributorFee);
    assertEq(configuration.controller, receivedConfig.controller);
  }
}

contract LW1155ClaimTest is BaseTest {
  function testOnlyCorrectReceiverCanClaim() public {
    vm.expectRevert(InvalidOwner.selector);

    uint256[] memory tokenIds = new uint256[](10);
    lw1155.claim(tokenIds, user2);
  }

  function testReceiverCanClaim() public {
    // mint to user1
    lw1155.mint(user1, rewardSplit, waterfallModule, configuration);

    // credit waterfall with 50 ETH
    vm.deal(waterfallModule, 50 ether);
    uint256 id = uint256(keccak256(abi.encodePacked(user1, waterfallModule)));

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = id;

    lw1155.claim(tokenIds, user1);

    // check the user1 balance is 41 ETH
    assertApproxEqAbs(user1.balance, 41 ether, 1);
  }
}

contract LW1155TransferTest is BaseTest {
  uint256 id;

  function testTransferAndNewOwnerClaim() public {
    // credit waterfall with 50 ETH
    vm.deal(waterfallModule, 50 ether);

    // mint to user1
    lw1155.mint(user1, rewardSplit, waterfallModule, configuration);

    id = uint256(keccak256(abi.encodePacked(user1, waterfallModule)));

    vm.expectEmit(true, true, true, true, address(lw1155));
    emit TransferSingle(user1, user1, user2, id, 1);

    vm.prank(user1);
    lw1155.safeTransferFrom(user1, user2, id, 1, "");

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = id;

    vm.prank(user2);
    lw1155.claim(tokenIds, user2);

    // reject if previous owner tries to claim
    vm.expectRevert(InvalidOwner.selector);
    vm.prank(user1);
    lw1155.claim(tokenIds, user1);
  }
}

contract LW1155RecoverTest is BaseTest {
  function testRecoverETH() public {
    vm.deal(address(lw1155), 10 ether);

    lw1155.recover(ERC20(address(0)), 5 ether);

    assertEq(obolTreasury.balance, 5 ether);

    lw1155.recover(ERC20(address(0)), 5 ether);

    assertEq(obolTreasury.balance, 10 ether);
  }

  function testRecoverToken() public {
    deal(address(mockERC20), address(lw1155), 10000);

    lw1155.recover(ERC20(address(mockERC20)), 5000);
    
    assertEq(mockERC20.balanceOf(obolTreasury), 5000);

    lw1155.recover(ERC20(address(mockERC20)), 5000);

    assertEq(mockERC20.balanceOf(obolTreasury), 10000);
  }
}