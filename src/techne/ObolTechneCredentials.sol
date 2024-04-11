// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {LibString} from "solady/utils/LibString.sol";
import {ERC721} from "solady/tokens/ERC721.sol";

contract ObolTechneCredentials is ERC721, OwnableRoles {
    string private _name;
    string private _symbol;
    string private _baseUri;

    uint256 public lastId;

    uint256 public constant MINTABLE_ROLE = 1111;

    error TokenNotTransferable();
    constructor(string memory name_, string memory symbol_, string memory baseUri_, address _owner) {
        _initializeOwner(_owner);

        _name = name_;
        _symbol = symbol_;
        _baseUri = baseUri_;

        lastId = 1;
    }

    /// -----------------------------------------------------------------------
    /// functions - view & pure
    /// -----------------------------------------------------------------------


    /// @dev Returns the token collection name.
    function name() public view override returns (string memory) {
        return _name;
    }

    /// @dev Returns the token collection symbol.
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /// @dev Returns the Uniform Resource Identifier (URI) for token `id`.
    function tokenURI(uint256 id) public view override returns (string memory) {
        if (!_exists(id)) revert TokenDoesNotExist();
        return string(abi.encodePacked(_baseUri, LibString.toString(id)));
    }
    
    /// @dev Returns the total amount of tokens stored by the contract.
    function totalSupply() public view virtual returns (uint256) {
        return lastId - 1;
    }

    /// -----------------------------------------------------------------------
    /// functions - public & external
    /// -----------------------------------------------------------------------

    /// @notice mints next ObolTechneCredetentials
    /// @param to receiver address
    /// @return mintedId id of the minted NFT
    function mint(address to) external onlyOwnerOrRoles(MINTABLE_ROLE) returns (uint256 mintedId) {
        _mint(to, lastId);
        mintedId = lastId;
        lastId++;
    }

    /// @notice safely mints next ObolTechneCredetentials
    /// @param to receiver address
    /// @return mintedId id of the minted NFT
    function safeMint(address to) external onlyOwnerOrRoles(MINTABLE_ROLE) returns (uint256 mintedId) {
        _safeMint(to, lastId);
        mintedId = lastId;
        lastId++;
    }


    /// @dev non-transferable
    function transferFrom(address, address, uint256) public payable override {
        revert TokenNotTransferable();
    }

    /// @dev non-transferable
    function safeTransferFrom(address, address, uint256) public payable override {
        revert TokenNotTransferable();
    }

    /// @dev non-transferable
    function safeTransferFrom(address, address, uint256, bytes calldata)
        public
        payable
        override
    {
        revert TokenNotTransferable();
    }
}