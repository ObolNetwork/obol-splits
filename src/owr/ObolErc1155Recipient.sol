// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ERC1155} from "solady/tokens/ERC1155.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {LibString} from "solady/utils/LibString.sol";
import {IOptimisticWithdrawalRecipient} from "../interfaces/IOptimisticWithdrawalRecipient.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract ObolErc1155Recipient is ERC1155, Ownable {
    using SafeTransferLib for address;

    uint256 public lastId;

    struct OWRInfo {
        address owr;
        address withdrawalAddress; 
    }

    mapping (uint256 => OWRInfo) public owrInfo;
    mapping(address owr => uint256 id) public assignedToOWR;
    mapping (address owr => mapping (uint256 id => uint256 claimable)) public rewards; 

    string private _baseUri;
    address private constant ETH_TOKEN_ADDRESS = address(0x0);
      
    error TokenNotTransferable();
    error TokenBatchMintLengthMismatch();
    error InvalidTokenAmount();
    error InvalidOwner();
    error InvalidOWR();
    error NothingToClaim();
    error ClaimFailed();
    
    constructor(string memory baseUri_, address _owner) {
        _initializeOwner(_owner);

        _baseUri = baseUri_;

        lastId = 1;
    }
    receive() external payable {}

    /// -----------------------------------------------------------------------
    /// functions - view & pure
    /// -----------------------------------------------------------------------
    /// @dev Returns the Uniform Resource Identifier (URI) for token `id`.
    function uri(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(_baseUri, LibString.toString(id)));
    }

    /// @dev Returns the total amount of tokens stored by the contract.
    function totalSupply() public view virtual returns (uint256) {
        return lastId - 1;
    }

    function isOwnerOf(uint256 id) public view returns (bool) {
        return balanceOf(msg.sender, id) > 0;
    }

    /// -----------------------------------------------------------------------
    /// functions - public & external
    /// -----------------------------------------------------------------------
    
    function receiveRewards(address owr) external onlyOwner {
        uint256 _tokenId = assignedToOWR[owr];

        // check if sender is owner of id
        if (!isOwnerOf(_tokenId)) revert InvalidOwner();

        // call .distribute() on OWR 
        uint256 balanceBefore = _getOWRTokenBalance(owr);
        IOptimisticWithdrawalRecipient(owr).distributeFunds();
        uint256 balanceAfter = _getOWRTokenBalance(owr);

        // update rewards[owr][id] += received;
        rewards[owr][_tokenId] += (balanceAfter - balanceBefore);
    }

    /// @notice claims rewards to `OWRInfo.withdrawalAddress`
    /// @dev callable by the owner
    /// @param id the ERC1155 id
    /// @return claimed the amount of rewards sent to `OWRInfo.withdrawalAddress`
    function claim(uint256 id) external returns (uint256 claimed) {
       claimed = _claim(id);
    }

    /// @notice claims rewards to `OWRInfo.withdrawalAddress` from multiple token ids
    /// @dev callable by the owner
    /// @param ids the ERC1155 ids
    /// @return claimed the amount of rewards sent to `OWRInfo.withdrawalAddress` per each id
    function batchClaim(uint256[] calldata ids) external returns (uint256[] memory claimed) {
        uint256 count = ids.length;
        for (uint256 i; i < count; i ++) {
            claimed[i] = _claim(ids[i]);
        }
    }

    
    /// @notice mints a new token
    /// @param to receiver address
    /// @param amount the amount for `lastId`
    /// @return mintedId id of the minted NFT
    function mint(address to, uint256 amount, OWRInfo calldata info) external onlyOwner returns (uint256 mintedId) {
        if (amount == 0) revert InvalidTokenAmount(); 
        _mint(to, lastId, amount, "");
        mintedId = _incrementId();
        owrInfo[mintedId] = info;
        assignedToOWR[info.owr] = mintedId;
    }

    /// @notice mints a batch of tokens
    /// @param to receiver address
    /// @param count batch length
    /// @param amounts the amounts for each id
    /// @param infos info per each id
    /// @return mintedIds id list of the minted NFTs
    function mintBatch(
        address to,
        uint256 count,
        uint256[] calldata amounts,
        OWRInfo[] calldata infos
    ) external onlyOwner returns (uint256[] memory mintedIds) {
        if (count != amounts.length) revert TokenBatchMintLengthMismatch();

        mintedIds = new uint256[](count);
        for (uint256 i;i < count; i++) {
            if (amounts[i] == 0) revert InvalidTokenAmount();
            _mint(to, lastId, amounts[i], "");
            mintedIds[i] = _incrementId();
            owrInfo[mintedIds[i]] = infos[i];
            assignedToOWR[infos[i].owr] = mintedIds[i];
        }
    }

    /// @dev non-transferable
    function safeTransferFrom(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public pure override {
        revert TokenNotTransferable();
    }

    /// @dev non-transferable
    function safeBatchTransferFrom(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) public pure override {
        revert TokenNotTransferable();
    }

    /// -----------------------------------------------------------------------
    /// functions - private
    /// -----------------------------------------------------------------------
    function _incrementId() public returns (uint256 mintedId) {
        mintedId = lastId;
        lastId++;
    }

    function _claim(uint256 id) private returns (uint256 claimed) {
        if (!isOwnerOf(id)) revert InvalidOwner();

       address _owr = owrInfo[id].owr;
       if (_owr == address(0)) revert InvalidOWR();

       claimed = rewards[_owr][id];
       if (claimed == 0) revert NothingToClaim();

        address token = IOptimisticWithdrawalRecipient(_owr).token();
        if (token == ETH_TOKEN_ADDRESS) {
            (bool sent,) = owrInfo[id].withdrawalAddress.call{value: claimed}("");
            if (!sent) revert ClaimFailed();
        } else {
            token.safeTransfer(owrInfo[id].withdrawalAddress, claimed);
        }
    }

    function _getOWRTokenBalance(address owr) private view returns (uint256 balance) {
        address token = IOptimisticWithdrawalRecipient(owr).token();
        if (token == ETH_TOKEN_ADDRESS) {
            balance = address(this).balance;
        } else {
            balance = ERC20(token).balanceOf(address(this));
        }
    }

}