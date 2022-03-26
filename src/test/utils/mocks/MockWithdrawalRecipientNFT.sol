// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "solmate/tokens/ERC721.sol";
import "solmate/auth/Auth.sol";

import { WithdrawalRecipientNFT } from "../../../WithdrawalRecipientNFT.sol";

contract MockWithdrawalRecipientNFT is WithdrawalRecipientNFT {
    constructor(ERC721 nftContract) WithdrawalRecipientNFT(nftContract, 0, msg.sender, Authority(address(0))) {}
}
