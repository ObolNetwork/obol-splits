// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IETH2DepositContract} from "../interfaces/IETH2DepositContract.sol";
import { HandlerContext } from "safe-contracts/handler/HandlerContext.sol";


contract ETHVaultSafeModule is ERC20, HandlerContext {
    using SafeTransferLib for address;

    IETH2DepositContract immutable public depositContract;

    constructor(address eth2DepositContract) {
        depositContract = IETH2DepositContract(eth2DepositContract);
    }

    function name() public view override returns (string memory) {
        // return 
    }

    function symbol() public view override returns (string memory) {

    }

    function depositValidator(
        bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root,
        uint256 amount
    ) external payable {
        bytes memory data = abi.encodeCall(depositContract.deposit, )
        depositContract.deposit{value: amount}(
            pubkey,
            withdrawal_credentials,
            signature,
            deposit_data_root
        );
    }

    function _deposit(address to, uint256 amount) internal {
        _mint(to, amount);
    }

    function redeem(address to, uint256 amount) external {
        _burn(msg.sender, amount);
        to.safeTransferETH(amount);
    }

    receive() external payable {
        _deposit(msg.sender, msg.value);
    }

}