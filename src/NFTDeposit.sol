// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import "ds-test/test.sol";
import "solmate/tokens/ERC721.sol";

error DoesNotExist();

/// @notice Deposit contract wrapper which mints an NFT on successful deposit.
/// @author Obol Labs Inc. (https://github.com/ObolNetwork)
contract NFTDeposit is ERC721 {
  /*///////////////////////////////////////////////////////////////
                                  IMMUTABLES
    //////////////////////////////////////////////////////////////*/

  IDepositContract public immutable depositContract;

  /*///////////////////////////////////////////////////////////////
                                  VARIABLES
    //////////////////////////////////////////////////////////////*/

  uint256 public totalSupply;
  string public baseURI;

  /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

  constructor(
    IDepositContract _depositContract,
    string memory name,
    string memory symbol,
    string memory _baseURI
  ) ERC721(name, symbol) {
    depositContract = _depositContract;
    baseURI = _baseURI;
  }

  /*///////////////////////////////////////////////////////////////
                            DEPOSIT LOGIC
    //////////////////////////////////////////////////////////////*/

  function deposit(
    bytes calldata pubkey,
    bytes calldata withdrawal_credentials,
    bytes calldata signature,
    bytes32 deposit_data_root
  ) external payable returns (uint256) {
    depositContract.deposit{value: msg.value}(
      pubkey, withdrawal_credentials, signature, deposit_data_root
    );

    uint256 id = totalSupply;
    _mint(msg.sender, id);
    totalSupply++;
    return id;
  }

  function tokenURI(uint256 id) public view override returns (string memory) {
    if (ownerOf[id] == address(0)) revert DoesNotExist();

    return string(abi.encodePacked(baseURI, id));
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
