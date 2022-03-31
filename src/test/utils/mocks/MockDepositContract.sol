// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import { IDepositContract } from "../../../NFTDeposit.sol";

contract MockDepositContract is IDepositContract {
    function deposit(
        bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root
    ) external payable {}
}
