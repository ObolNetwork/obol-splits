// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "solmate/tokens/ERC721.sol";

/// @notice Deposit contract wrapper which mints an NFT on successful deposit.
/// @author Obol Labs Inc. (https://github.com/ObolNetwork(
contract NFTDeposit is ERC721 {
    /*///////////////////////////////////////////////////////////////
                                  IMMUTABLES
    //////////////////////////////////////////////////////////////*/

   IDepositContract public immutable depositContract;

    /*///////////////////////////////////////////////////////////////
                                  VARIABLES
    //////////////////////////////////////////////////////////////*/

   uint256 public totalSupply;

    /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

   constructor(IDepositContract _depositContract) ERC721(name, symbol) {
       depositContract = _depositContract;
   }

    /*///////////////////////////////////////////////////////////////
                            DEPOSIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root
    ) external payable {
        depositContract.deposit.value(msg.value)(pubkey, withdrawal_credentials, signature, deposit_data_root);

        _mint(msg.sender, totalSupply);
        totalSupply++;
    }
}

interface IDepositContract {
    /// @notice Submit a Phase 0 DepositData object.
    /// @param pubkey A BLS12-381 public key.
    /// @param withdrawal_credentials Commitment to a public key for withdrawals.
    /// @param signature A BLS12-381 signature.
    /// @param deposit_data_root The SHA-256 hash of the SSZ-encoded DepositData object.
    /// Used as a protection against malformed input.
    function deposit(
        bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root
    ) external payable;
}
