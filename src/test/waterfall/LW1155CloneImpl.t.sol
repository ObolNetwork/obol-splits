// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/waterfall/token/LW1155CloneImpl.sol";

contract LW1155CloneImplTest is Test {

    LW1155CloneImpl public lw1155CloneImpl;

    function setUp() public {
        lw1155CloneImpl = new LW1155CloneImpl();
    }

    function testCanInitialize() public {
        address[] memory accounts = new address[](3);
        accounts[0] = makeAddr("first");
        accounts[1] = makeAddr("second");
        accounts[2] = makeAddr("third");

        lw1155CloneImpl.initialize(accounts);

        // check this contract is the owner
        assertEq(lw1155CloneImpl.owner(), address(this));
        
        // check all tokens are properly minted
        assertEq(lw1155CloneImpl.balanceOf(accounts[0], 0), 1);
        assertEq(lw1155CloneImpl.balanceOf(accounts[1], 1), 1);
        assertEq(lw1155CloneImpl.balanceOf(accounts[2], 2), 1);

        // cannot double intiailize
        vm.expectRevert(lw1155CloneImpl.Initialized.selector);
        lw1155CloneImpl.initialize(accounts);
    }

    function testCanFetchUri() public {
        lw1155CloneImpl.uri(0);
    }

    function testCanFetchName() public {
        assertEq(
            lw1155CloneImpl.name(),
            string.concat(
                "Obol Liquid Waterfall Split ", address(lw1155CloneImpl)
            )
        );
    }

    // @TODO add fuzz tests
}