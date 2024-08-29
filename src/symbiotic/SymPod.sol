// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import {ICollateral} from "collateral/interfaces/ICollateral.sol";

contract SymPod is ICollateral {

    /// @dev address used as ETH token
    address public constant ETH_ADDRESS = 0x0;

    /// @inheritdoc 
    function asset() external view returns (address) {
        return ETH_ADDRESS;
    }

    function totalRepaidDebt() external view returns (uint256) {

    }

    function issuerRepaidDebt(address issuer) external view returns (uint256) {

    }

    function recipientRepaidDebt(address recipient) external view returns (uint256) {

    }

    function repaidDebt(address issuer, address recipient) external view returns (uint256) {

    }

    function totalDebt() external view returns (uint256) {

    }

    function issuerDebt(address issuer) external view returns (uint256) {

    }


    function recipientDebt(address recipient) external view returns (uint256) {

    }

    function debt(address issuer, address recipient) external view returns (uint256) {

    }

    function issueDebt(address recipient, uint256 amount) external {

    }
}