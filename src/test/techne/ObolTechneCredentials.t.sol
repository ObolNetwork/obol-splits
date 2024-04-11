// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ObolTechneCredentials} from "src/techne/ObolTechneCredentials.sol";

//TODO: test safeMint
contract ObolTechneCredentialsTest is Test {

    ObolTechneCredentials credentials;
    address userWithMinterRole;
    address userWithoutMinterRole;


    string constant NAME = "Test";
    string constant SYMBOL = "TST";
    string constant BASE_URI = "https://github.com";

    function setUp() public {
        credentials = new ObolTechneCredentials(NAME, SYMBOL, BASE_URI, address(this));

        userWithMinterRole = makeAddr("userWithMinterRole");
        userWithoutMinterRole = makeAddr("userWithoutMinterRole");
    }

    function testName() public {
        assertEq(credentials.name(), NAME);
    }

    function testSymbol() public {
        assertEq(credentials.symbol(), SYMBOL);
    }

    function testInitialSupply() public {
        assertEq(credentials.totalSupply(), 0);
    }

    function testMint() public {
        credentials.mint(address(this));
        address ownerOf1 = credentials.ownerOf(1);
        assertEq(ownerOf1, address(this));

        vm.expectRevert();
        credentials.safeMint(address(this));

        // test `userWithMinterRole` roles 
        vm.startPrank(userWithoutMinterRole);
        vm.expectRevert();
        credentials.mint(address(this));
        vm.stopPrank();

        // test `userWithMinterRole` roles 
        credentials.grantRoles(userWithMinterRole, credentials.MINTABLE_ROLE());
        vm.prank(userWithMinterRole);
        credentials.mint(userWithMinterRole);
        address ownerOf2 = credentials.ownerOf(2);
        assertEq(ownerOf2, userWithMinterRole);
    }

    function testTransfer() public {
        credentials.mint(address(this));

        vm.expectRevert();
        credentials.transferFrom(address(this), userWithMinterRole, 1);
    }

    function testSafeTransfer() public {
        credentials.mint(address(this));

        vm.expectRevert();
        credentials.safeTransferFrom(address(this), userWithMinterRole, 1);

        vm.expectRevert();
        credentials.safeTransferFrom(address(this), userWithMinterRole, 1, "");
    }
}