// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "ds-test/test.sol";

import "./utils/mocks/MockSplitter.sol";
import "./utils/mocks/MockSplitterDeployer.sol";

contract SplitterTest is DSTest {
    MockSplitterDeployer mockSplitterDeployer;
    MockSplitter mockSplitter;

    function setUp() public {
        mockSplitter = new MockSplitter();
        mockSplitterDeployer = new MockSplitterDeployer(mockSplitter, address(0x0B01));
    }

    function testFailCallWithoutAccounts() public {
        address[] memory accounts = new address[](0);
        mockSplitterDeployer.deploy(accounts);
    }

    function testCallDeploy() public {
        address[] memory accounts = new address[](3);
        accounts[0] = address(0xABEE);
        accounts[1] = address(0xBEEF);
        accounts[2] = address(0xCAFE);
        address returnal = mockSplitterDeployer.deploy(accounts);

        assertEq(returnal, address(0xFFFF));

        assertEq(mockSplitter.showSplitRecipient(0), accounts[0]);
        assertEq(mockSplitter.showSplitRecipient(1), accounts[1]);
        assertEq(mockSplitter.showSplitRecipient(2), accounts[2]);
        assertEq(mockSplitter.showSplitRecipient(3), address(0x0B01));

        assertEq(mockSplitter.showSplitAllocation(0), 320000);
        assertEq(mockSplitter.showSplitAllocation(1), 320000);
        assertEq(mockSplitter.showSplitAllocation(2), 320000);
        assertEq(mockSplitter.showSplitAllocation(3), 40000);

        assertEq(mockSplitter.showController(), address(this));
    }

    function testCallDeploy7() public {
        uint256 splitCnt = 7;
        uint160 firstAddr = 0x0A00;
        address[] memory accounts = new address[](splitCnt);
        for (uint256 i = 0; i < splitCnt; i++) {
            accounts[i] = address(firstAddr);
            firstAddr += 1;
        }

        address returnal = mockSplitterDeployer.deploy(accounts);
        assertEq(returnal, address(0xFFFF));

        for (uint256 i = 0; i < splitCnt; i++) {
            assertEq(mockSplitter.showSplitRecipient(i), accounts[i]);
        }
        assertEq(mockSplitter.showSplitRecipient(splitCnt), address(0x0B01));

        for (uint256 i = 0; i < splitCnt; i++) {
            assertEq(mockSplitter.showSplitAllocation(i), 137142);
        }
        assertEq(mockSplitter.showSplitAllocation(splitCnt), 40006);

        assertEq(mockSplitter.showController(), address(this));
    }
}
