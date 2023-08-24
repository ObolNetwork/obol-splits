// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;
import "forge-std/Test.sol";
import {
    ImmutableSplitControllerFactory,
    ImmutableSplitController
} from "src/controllers/ImmutableSplitControllerFactory.sol";
import {ISplitMain} from "src/interfaces/ISplitMain.sol";


contract IMSCFactory is Test {

    address internal SPLIT_MAIN_GOERLI = 0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE;

    ImmutableSplitControllerFactory public factory;
    ImmutableSplitController public cntrlImpl;

    address[] accounts;
    uint32[]  percentAllocations;

    function setUp() public {
        uint256 goerliBlock = 8_529_931;
        vm.createSelectFork(getChain("goerli").rpcUrl, goerliBlock);

        factory = new ImmutableSplitControllerFactory(SPLIT_MAIN_GOERLI);
        cntrlImpl = factory.controller();

        accounts = new address[](2);
        accounts[0] = makeAddr("accounts0");
        accounts[1] = makeAddr("accounts1");

        percentAllocations = new uint32[](2);
        percentAllocations[0] = 400_000;
        percentAllocations[1] = 600_000;
    }

    function test_createController() public {
        address split = ISplitMain(SPLIT_MAIN_GOERLI).createSplit(
            accounts,
            percentAllocations,
            0,
            address(0)
        );

        ImmutableSplitController controller = factory.createController(
            split,
            accounts,
            percentAllocations,
            0,
            keccak256(abi.encodePacked(uint256(12)))
        );

        address predictedAddress = factory.predictSplitControllerAddress(
            accounts,
            percentAllocations,
            0,
            keccak256(abi.encodePacked(uint256(12)))
        );

        assertEq(address(controller), predictedAddress, "predicted_address_invalid");
    }

}