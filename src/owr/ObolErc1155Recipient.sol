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

  struct TokenInfo {
    address owr;
    uint256 activeSupply;
    address rewardAddress;
    uint256 claimable;
  }

  struct DepositInfo {
    bytes pubkey;
    bytes withdrawal_credentials;
    bytes sig;
  }

  mapping(uint256 id => TokenInfo) public tokenInfo;
  mapping(address owr => uint256) public owrTokens;

  mapping(uint256 id => uint256) public totalSupply;
  uint256 public totalSupplyAll;

  string private _baseUri;
  address private constant ETH_TOKEN_ADDRESS = address(0x0);
  uint256 private constant ETH_DEPOSIT_AMOUNT = 32 ether;

  error LengthMismatch();
  error InvalidTokenAmount();
  error InvalidOwner();
  error InvalidOWR();
  error NothingToClaim();
  error ClaimFailed();
  error InvalidDepositContract();
  error InvalidLastSupply();

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

  /// @dev Returns true if `msg.sender` is the owner of the contract
  function isOwnerOf(uint256 id) public view returns (bool) {
    return balanceOf(msg.sender, id) > 0;
  }

  /// -----------------------------------------------------------------------
  /// functions - onlyOwner
  /// -----------------------------------------------------------------------
  /// @notice sets the ETH DepositContract
  /// @dev callable by the owner
  /// @param depositContract the `DepositContract` address
  function setDepositContract(address depositContract) external onlyOwner {
    if (depositContract == address(0)) revert InvalidDepositContract();
    emit DepositContractUpdated(address(ethDepositContract), depositContract);
    ethDepositContract = IDepositContract(depositContract);
  }

  /// -----------------------------------------------------------------------
  /// functions - public & external
  /// -----------------------------------------------------------------------
  /// @notice triggers `OWR.distributeFunds`
  /// @dev callable by the owner
  /// @param owr the OWR address
  function receiveRewards(address owr) external {
    uint256 _tokenId = owrTokens[owr];

    // check if sender is owner of id
    if (!isOwnerOf(_tokenId)) revert InvalidOwner();

    // call .distribute() on OWR
    uint256 balanceBefore = _getOWRTokenBalance(owr);
    IOptimisticWithdrawalRecipient(owr).distributeFunds();
    uint256 balanceAfter = _getOWRTokenBalance(owr);

    tokenInfo[_tokenId].claimable += (balanceAfter - balanceBefore);
  }

  /// @notice claims rewards to `TokenInfo.rewardAddress`
  /// @dev callable by the owner
  /// @param id the ERC1155 id
  /// @return claimed the amount of rewards sent to `TokenInfo.rewardAddress`
  function claim(uint256 id) external returns (uint256 claimed) {
    claimed = _claim(id);
  }

  /// @notice claims rewards to `TokenInfo.rewardAddress` from multiple token ids
  /// @dev callable by the owner
  /// @param ids the ERC1155 ids
  /// @return claimed the amount of rewards sent to `TokenInfo.rewardAddress` per each id
  function batchClaim(uint256[] calldata ids) external returns (uint256[] memory claimed) {
    uint256 count = ids.length;
    for (uint256 i; i < count; i++) {
      claimed[i] = _claim(ids[i]);
    }
  }

  /// @notice mints a new token
  /// @dev supply can be increased later with `mintSupply`
  /// @param to receiver address
  /// @param amount the amount for `lastId`
  /// @param owr OptimisticWithdrawalRecipient address
  /// @param rewardAddress rewards receiver address
  /// @return mintedId id of the minted NFT
  function mint(address to, uint256 amount, address owr, address rewardAddress)
    external
    payable
    onlyOwner
    returns (uint256 mintedId)
  {
    // validation
    if (amount == 0) revert InvalidTokenAmount();

    // mint
    mintedId = _assignInfoAndExtractId(owr, rewardAddress);
    _mint(to, mintedId, amount, "");

    // increase total supply
    totalSupply[mintedId] += amount;
    totalSupplyAll += amount;
  }

  /// @notice mints a batch of tokens
  /// @dev supply can be increased later with `mintSupply`
  /// @param to receiver address
  /// @param count batch length
  /// @param amounts the amounts for each id
  /// @param owrs OptimisticWithdrawalRecipient addresses
  /// @param rewardAddresses rewards receiver addresses
  /// @return mintedIds id list of the minted NFTs
  function mintBatch(
    address to,
    uint256 count,
    uint256[] calldata amounts,
    address[] calldata owrs,
    address[] calldata rewardAddresses
  ) external payable onlyOwner returns (uint256[] memory mintedIds) {
    // validate
    if (count != amounts.length) revert LengthMismatch();
    if (count != owrs.length) revert LengthMismatch();
    if (count != rewardAddresses.length) revert LengthMismatch();

    // mint up to `count`
    mintedIds = new uint256[](count);
    for (uint256 i; i < count; i++) {
      if (amounts[i] == 0) revert InvalidTokenAmount();
      mintedIds[i] = _assignInfoAndExtractId(owrs[i], rewardAddresses[i]);
      _mint(to, mintedIds[i], amounts[i], "");

      // increase total supply
      totalSupply[mintedIds[i]] += amounts[i];
      totalSupplyAll += amounts[i];
    }
  }

  /// @notice deposits ETH to `DepositContract` and activates part of supply
  /// @param id token id
  /// @param count amount of supply to activate
  /// @param depositInfo deposit data needed for `DepositContract`
  function depositForToken(uint256 id, uint256 count, DepositInfo[] calldata depositInfo) external payable {
    // vaidate
    if (!isOwnerOf(id)) revert InvalidOwner();

    if (depositInfo.length != count) revert LengthMismatch();

    uint256 crtActiveSupply = tokenInfo[id].activeSupply;
    if (crtActiveSupply + count >= totalSupply[id]) revert InvalidLastSupply();

    if (msg.value < count * ETH_DEPOSIT_AMOUNT) revert InvalidTokenAmount();

    // deposit to ETH `DepositContract`
    for (uint i; i < count; i++) {
      ethDepositContract.deposit{value: ETH_DEPOSIT_AMOUNT}(
        depositInfo[i].pubkey, depositInfo[i].withdrawal_credentials, depositInfo[i].sig, ethDepositContract.get_deposit_root()
      );
    }
 
    // activate supply
    tokenInfo[id].activeSupply += count;
  }

  /// @notice increases totalSupply for token id
  /// @param id token id
  /// @param amount newly added supply
  function mintSupply(uint256 id, uint256 amount) external {
    // validate
    if (!isOwnerOf(id)) revert InvalidOwner();
    if (lastId < id) revert InvalidLastSupply();

    // mint for existing id
    _mint(msg.sender, id, amount, "");

    // increase total supply
    totalSupply[id] += amount;
    totalSupplyAll += amount;
  }

  /// @notice decreases totalSupply for token id
  /// @param id token id
  /// @param amount newly removed supply
  function burn(uint256 id, uint256 amount) external {
    // vaidate
    if (!isOwnerOf(id)) revert InvalidOwner();
    if (amount == 0) revert InvalidTokenAmount();

    _burn(msg.sender, id, amount);

    totalSupply[id] -= amount;
    totalSupplyAll -= amount;

    // burn should be initiated on activeSupply withdrawal, but
    // check just in case
    tokenInfo[id].activeSupply =(tokenInfo[id].activeSupply > amount ? tokenInfo[id].activeSupply - amount: 0);
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
      _claim(ids[i]); //allow transfer even if `claimed == 0`
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

  function _claim(uint256 id) private returns (uint256 claimed) {
    if (!isOwnerOf(id)) revert InvalidOwner();

    address _owr = tokenInfo[id].owr;
    if (_owr == address(0)) revert InvalidOWR();
    if (tokenInfo[id].claimable == 0) return 0;

    address token = IOptimisticWithdrawalRecipient(_owr).token();
    if (token == ETH_TOKEN_ADDRESS) {
      (bool sent,) = tokenInfo[id].rewardAddress.call{value: tokenInfo[id].claimable}("");
      if (!sent) revert ClaimFailed();
    } else {
      token.safeTransfer(tokenInfo[id].rewardAddress, tokenInfo[id].claimable);
    }
    tokenInfo[id].claimable = 0;
  }

  function _getOWRTokenBalance(address owr) private view returns (uint256 balance) {
    address token = IOptimisticWithdrawalRecipient(owr).token();
    if (token == ETH_TOKEN_ADDRESS) balance = address(this).balance;
    else balance = ERC20(token).balanceOf(address(this));
  }

  function _assignInfoAndExtractId(address owr, address rewardAddress) private returns (uint256 mintedId) {
    mintedId = _incrementId();

    TokenInfo memory info = TokenInfo({activeSupply: 0, claimable: 0, owr: owr, rewardAddress: rewardAddress});
    tokenInfo[mintedId] = info;
    owrTokens[info.owr] = mintedId;
  }
}
