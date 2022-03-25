// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { IDepositContract, NFTDeposit } from "../../../NFTDeposit.sol";

contract MockNFTDeposit is NFTDeposit {
    constructor(IDepositContract depositContract) NFTDeposit(depositContract, "Obol", "OBOL", "URI") {}
}

