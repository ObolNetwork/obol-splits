// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;
import "forge-std/Test.sol";
import {
    ImmutableSplitControllerFactory,
    ImmutableSplitController
} from "src/controllers/ImmutableSplitControllerFactory.sol";
import {ISplitMain} from "src/interfaces/ISplitMain.sol";


contract IMSCFactory is Test {

    error InvalidSplit__TooFewAccounts(uint256 accountsLength);
    error InvalidSplit__AccountsAndAllocationsMismatch(
        uint256 accountsLength,
        uint256 allocationsLength
    );
    error InvalidSplit__InvalidAllocationsSum(uint32 allocationsSum);
    error InvalidSplit__AccountsOutOfOrder(uint256 index);
    error InvalidSplit__AllocationMustBePositive(uint256 index);
    error InvalidSplit__InvalidDistributorFee(uint32 distributorFee);


    address internal SPLIT_MAIN_GOERLI = 0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE;
    uint32 public constant SPLIT_MAIN_PERCENTAGE_SCALE = 1e6;

    ImmutableSplitControllerFactory public factory;
    ImmutableSplitController public cntrlImpl;

    address owner;

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

        owner = makeAddr("owner");
    }
    
    function test_RevertIfAccountSizeIsOne() public {
        address[] memory newAccounts = new address[](1);
        newAccounts[0] = makeAddr("testRevertIfAccountSizeIsOne");

        vm.expectRevert(
            abi.encodeWithSelector(InvalidSplit__TooFewAccounts.selector, newAccounts.length)
        );

        factory.createController(
            address(1),
            owner,
            newAccounts,
            percentAllocations,
            0,
             keccak256(abi.encodePacked(uint256(12)))
        );
    }

    function test_RevertIfAccountAndAllocationMismatch() public {
        uint32[] memory newPercentAllocations = new uint32[](3);
        newPercentAllocations[0] = 200_000;
        newPercentAllocations[1] = 200_000;
        newPercentAllocations[2] = 600_000;

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidSplit__AccountsAndAllocationsMismatch.selector,
                accounts.length,
                newPercentAllocations.length
            )
        );

        factory.createController(
            address(1),
            owner,
            accounts,
            newPercentAllocations,
            0,
            keccak256(abi.encodePacked(uint256(12)))
        );
    }


    function test_RevertIfAccountOutOfOrder() public {
        address[] memory newAccounts = new address[](2);
        newAccounts[0] = address(0x4);
        newAccounts[1] = address(0x1);

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidSplit__AccountsOutOfOrder.selector,
                0
            )
        );

        factory.createController(
            address(1),
            owner,
            newAccounts,
            percentAllocations,
            0,
            keccak256(abi.encodePacked(uint256(12)))
        );
    }

    function test_RevertIfZeroPercentAllocation() public {
        uint32[] memory newPercentAllocations = new uint32[](2);
        newPercentAllocations[0] = SPLIT_MAIN_PERCENTAGE_SCALE;
        newPercentAllocations[1] = 0;

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidSplit__AllocationMustBePositive.selector,
                1
            )
        );

        factory.createController(
            address(1),
            owner,
            accounts,
            newPercentAllocations,
            0,
            keccak256(abi.encodePacked(uint256(12)))
        );
    }

    function test_RevertIfInvalidDistributorFee() public {
        uint32 invalidDistributorFee = 1e6;
        
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidSplit__InvalidDistributorFee.selector,
                invalidDistributorFee
            )
        );

        factory.createController(
            address(1),
            owner,
            accounts,
            percentAllocations,
            invalidDistributorFee,
            keccak256(abi.encodePacked(uint256(12)))
        );
    }

    function test_RevertIfInvalidAllocationSum() public {
        uint32[] memory newPercentAllocations = new uint32[](2);
        newPercentAllocations[0] = SPLIT_MAIN_PERCENTAGE_SCALE;
        newPercentAllocations[1] = 1;

         vm.expectRevert(
            abi.encodeWithSelector(
                InvalidSplit__InvalidAllocationsSum.selector,
                SPLIT_MAIN_PERCENTAGE_SCALE + 1
            )
        );

        factory.createController(
            address(1),
            owner,
            accounts,
            newPercentAllocations,
            0,
            keccak256(abi.encodePacked(uint256(12)))
        );
    }

    function test_CanCreateController() public {
        bytes32 deploymentSalt =  keccak256(abi.encodePacked(uint256(1102)));

        address predictedAddress = factory.predictSplitControllerAddress(
            owner,
            accounts,
            percentAllocations,
            0,
            deploymentSalt
        );

        address split = ISplitMain(SPLIT_MAIN_GOERLI).createSplit(
            accounts,
            percentAllocations,
            0,
            predictedAddress
        );

        ImmutableSplitController controller = factory.createController(
            split,
            owner,
            accounts,
            percentAllocations,
            0,
            deploymentSalt
        );

        assertEq(address(controller), predictedAddress, "predicted_address_invalid");
    }

}