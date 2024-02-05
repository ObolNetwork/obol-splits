// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import "forge-std/Test.sol";
import { ObolEigenLayerPodControllerFactory } from "src/eigenlayer/ObolEigenLayerPodControllerFactory.sol";

contract ObolEigenLayerPodControllerFactoryTest is Test {
    error Invalid_Owner();
    error Invalid_OWR();
    error Invalid_DelegationManager();
    error Invalid_EigenPodManaager();
    error Invalid_WithdrawalRouter();
    
    event CreatePodController(
        address indexed controller,
        address indexed split,
        address owner
    );

    address DELEGATION_MANAGER_GOERLI = 0x1b7b8F6b258f95Cf9596EabB9aa18B62940Eb0a8;
    address POD_MANAGER_GOERLI = 0xa286b84C96aF280a49Fe1F40B9627C2A2827df41;
    address DELAY_ROUTER_GOERLI = 0x89581561f1F98584F88b0d57c2180fb89225388f;

    ObolEigenLayerPodControllerFactory factory;

    address owner;
    address user1;
    address splitter;
    address feeRecipient;

    uint256 feeShare;

    function setUp() public {
        uint256 goerliBlock = 10_205_449;
        vm.createSelectFork(getChain("goerli").rpcUrl, goerliBlock);

        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        splitter = makeAddr("splitter");
        feeRecipient = makeAddr("feeRecipient");
        feeShare = 1e3;

        factory = new ObolEigenLayerPodControllerFactory(
            feeRecipient,
            feeShare,
            DELEGATION_MANAGER_GOERLI,
            POD_MANAGER_GOERLI,
            DELAY_ROUTER_GOERLI
        );
    }

    function test_RevertIfInvalidDelegationManger() external {
        vm.expectRevert(Invalid_DelegationManager.selector);
        new ObolEigenLayerPodControllerFactory(
            feeRecipient,
            feeShare,
            address(0),
            POD_MANAGER_GOERLI,
            DELAY_ROUTER_GOERLI
        );
    }
    
    function test_RevertIfInvalidPodManger() external {
        vm.expectRevert(Invalid_EigenPodManaager.selector);
        new ObolEigenLayerPodControllerFactory(
            feeRecipient,
            feeShare,
            DELEGATION_MANAGER_GOERLI,
            address(0),
            DELAY_ROUTER_GOERLI
        );
    }

    function test_RevertIfInvalidWithdrawalRouter() external {
        vm.expectRevert(Invalid_WithdrawalRouter.selector);
        new ObolEigenLayerPodControllerFactory(
            feeRecipient,
            feeShare,
            DELEGATION_MANAGER_GOERLI,
            POD_MANAGER_GOERLI,
            address(0)
        );
    }

    function test_RevertIfOwnerIsZero() external {
        vm.expectRevert(Invalid_Owner.selector);
        factory.createPodController(
            address(0),
            splitter
        );
    }

    function test_RevertIfOWRIsZero() external {
        vm.expectRevert(Invalid_OWR.selector);
        factory.createPodController(
            user1,
            address(0)
        );
    }

    function test_CreatePodController() external {
        vm.expectEmit(
            false,
            false,
            false,
            true
        );

        emit CreatePodController(
            address(0),
            splitter,
            user1
        );

        factory.createPodController(
            user1,
            splitter
        );
    }
}