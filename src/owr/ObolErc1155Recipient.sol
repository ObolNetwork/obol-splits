// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ERC1155} from "solady/tokens/ERC1155.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {LibString} from "solady/utils/LibString.sol";
import {IDepositContract} from "../interfaces/IDepositContract.sol";
import {IOptimisticWithdrawalRecipient} from "../interfaces/IOptimisticWithdrawalRecipient.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract ObolErc1155Recipient is ERC1155, Ownable {
  using SafeTransferLib for address;

  uint256 public lastId;
  IDepositContract public ethDepositContract;

  struct OWRInfo {
    address owr;
    address rewardAddress;
  }

  struct DepositInfo {
    bytes pubkey;
    bytes withdrawal_credentials;
    bytes sig;
  }

  mapping(uint256 => OWRInfo) public owrInfo;
  mapping(address owr => uint256 id) public assignedToOWR;
  mapping(address owr => mapping(uint256 id => uint256 claimable)) public rewards;

  string private _baseUri;
  address private constant ETH_TOKEN_ADDRESS = address(0x0);
  uint256 private constant ETH_DEPOSIT_AMOUNT = 32 ether;

  error TokenNotTransferable();
  error TokenBatchMintLengthMismatch();
  error InvalidTokenAmount();
  error InvalidOwner();
  error InvalidOWR();
  error NothingToClaim();
  error ClaimFailed();
  error InvalidDepositContract();

  event DepositContractUpdated(address oldAddy, address newAddy);

  constructor(string memory baseUri_, address _owner, address _depositContract) {
    if (_depositContract == address(0)) revert InvalidDepositContract();

    lastId = 1;
    _baseUri = baseUri_;
    ethDepositContract = IDepositContract(_depositContract);

    _initializeOwner(_owner);
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
  /// @notice sets the ETH DepositContract
  /// @dev callable by the owner
  /// @param depositContract the `DepositContract` address
  function setDepositContract(address depositContract) external onlyOwner {
    if (depositContract == address(0)) revert InvalidDepositContract();
    emit DepositContractUpdated(address(ethDepositContract), depositContract);
    ethDepositContract = IDepositContract(depositContract);
  }

  /// @notice triggers `OWR.distributeFunds`
  /// @dev callable by the owner
  /// @param owr the OWR address
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

  /// @notice claims rewards to `OWRInfo.rewardAddress`
  /// @dev callable by the owner
  /// @param id the ERC1155 id
  /// @return claimed the amount of rewards sent to `OWRInfo.rewardAddress`
  function claim(uint256 id) external returns (uint256 claimed) {
    claimed = _claim(id, false);
  }

  /// @notice claims rewards to `OWRInfo.rewardAddress` from multiple token ids
  /// @dev callable by the owner
  /// @param ids the ERC1155 ids
  /// @return claimed the amount of rewards sent to `OWRInfo.rewardAddress` per each id
  function batchClaim(uint256[] calldata ids) external returns (uint256[] memory claimed) {
    uint256 count = ids.length;
    for (uint256 i; i < count; i++) {
      claimed[i] = _claim(ids[i], false);
    }
  }

  /// @notice mints a new token
  /// @param to receiver address
  /// @param amount the amount for `lastId`
  /// @return mintedId id of the minted NFT
  function mint(address to, uint256 amount, OWRInfo calldata info, DepositInfo calldata depositInfo)
    external
    payable
    onlyOwner
    returns (uint256 mintedId)
  { 
    // validation
    if (amount == 0) revert InvalidTokenAmount();
    uint256 totalETH = ETH_DEPOSIT_AMOUNT * amount;
    if (msg.value != totalETH) revert InvalidTokenAmount();
    
    // mint 
    _mint(to, lastId, amount, "");
    mintedId = _afterMint(info, depositInfo, totalETH);
  }


  /// @notice mints a batch of tokens
  /// @param to receiver address
  /// @param count batch length
  /// @param amounts the amounts for each id
  /// @param infos info per each id
  /// @return mintedIds id list of the minted NFTs
  function mintBatch(address to, uint256 count, uint256[] calldata amounts, OWRInfo[] calldata infos, DepositInfo calldata depositInfo)
    external
    payable
    onlyOwner
    returns (uint256[] memory mintedIds)
  {
    if (count != amounts.length) revert TokenBatchMintLengthMismatch();
    uint256 totalETH;
    for (uint256 i; i < count; i++) {
        totalETH += (ETH_DEPOSIT_AMOUNT * amounts[i]);
    }
    if (totalETH != msg.value) revert InvalidTokenAmount();

    mintedIds = new uint256[](count);
    for (uint256 i; i < count; i++) {
        if (amounts[i] == 0) revert InvalidTokenAmount();
        uint256 totalIndexETH = ETH_DEPOSIT_AMOUNT * amounts[i];
        _mint(to, lastId, amounts[i], "");
        mintedIds[i] = _afterMint(infos[i], depositInfo, totalIndexETH);
    }
  }

  /// @dev Hook that is called before any token transfer.
  ///      Forces claim before a transfer happens
  function _beforeTokenTransfer(address from, address to, uint256[] memory ids, uint256[] memory, bytes memory)
    internal
    override
  {
    // skip for mint or burn
    if (from == address(0) || to == address(0)) return;

    // claim before transfer
    uint256 length = ids.length;
    for (uint256 i; i < length; i++) {
      _claim(ids[i], true); //allow transfer even if `claimed == 0`
    }
  }

  /// -----------------------------------------------------------------------
  /// functions - private
  /// -----------------------------------------------------------------------
  function _useBeforeTokenTransfer() internal pure override returns (bool) {
    return true;
  }

  function _incrementId() public returns (uint256 mintedId) {
    mintedId = lastId;
    lastId++;
  }

  function _claim(uint256 id, bool canSkipAmountCheck) private returns (uint256 claimed) {
    if (!isOwnerOf(id)) revert InvalidOwner();

    address _owr = owrInfo[id].owr;
    if (_owr == address(0)) revert InvalidOWR();

    claimed = rewards[_owr][id];
    if (claimed == 0 && !canSkipAmountCheck) revert NothingToClaim();

    address token = IOptimisticWithdrawalRecipient(_owr).token();
    if (token == ETH_TOKEN_ADDRESS) {
      (bool sent,) = owrInfo[id].rewardAddress.call{value: claimed}("");
      if (!sent) revert ClaimFailed();
    } else {
      token.safeTransfer(owrInfo[id].rewardAddress, claimed);
    }
  }

  function _getOWRTokenBalance(address owr) private view returns (uint256 balance) {
    address token = IOptimisticWithdrawalRecipient(owr).token();
    if (token == ETH_TOKEN_ADDRESS) balance = address(this).balance;
    else balance = ERC20(token).balanceOf(address(this));
  }

  
  function _afterMint(OWRInfo calldata info, DepositInfo calldata depositInfo, uint256 totalETH) private returns (uint256 mintedId) {
    mintedId = _incrementId();
    owrInfo[mintedId] = info;
    assignedToOWR[info.owr] = mintedId;

    // deposit to ETH `DepositContract`
    ethDepositContract.deposit{value: totalETH}(
      depositInfo.pubkey,
      depositInfo.withdrawal_credentials,
      depositInfo.sig,
      ethDepositContract.get_deposit_root()
    );
  }
}
