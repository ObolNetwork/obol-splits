// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;
import "forge-std/Test.sol";
import {
    ImmutableSplitControllerFactory,
    ImmutableSplitController
} from "src/controllers/ImmutableSplitControllerFactory.sol";
import {ISplitMain} from "src/interfaces/ISplitMain.sol";


contract IMSC is Test {

    address internal SPLIT_MAIN_GOERLI = 0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE;

    ImmutableSplitControllerFactory public factory;
    ImmutableSplitController public cntrlImpl;

    ImmutableSplitController public controller;

    address[] accounts;
    uint32[]  percentAllocations;

    address[] controllerAccounts;
    uint32[] controllerPercentAllocations;

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

        controllerAccounts = new address[](3);
        controllerAccounts[0] = makeAddr("accounts0");
        controllerAccounts[1] = makeAddr("accounts1");
        controllerAccounts[2] = makeAddr("accounts2");

        controllerPercentAllocations = new uint32[](3);
        controllerPercentAllocations[0] = 400_000;
        controllerPercentAllocations[1] = 300_000;
        controllerPercentAllocations[2] = 300_000;

        bytes32 deploymentSalt = keccak256(abi.encodePacked(uint256(64)));
        
        // predict controller address
        address controller = factory.predictSplitControllerAddress(
            split,
            controllerAccounts,
            controllerPercentAllocations,
            0,
            keccak256(abi.encodePacked(uint256(64)))
        );

        address split = ISplitMain(SPLIT_MAIN_GOERLI).createSplit(
            accounts,
            percentAllocations,
            0,
            controller
        );

        // deploy controller 


    }

}