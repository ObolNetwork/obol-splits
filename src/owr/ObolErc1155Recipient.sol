// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ERC1155} from "solady/tokens/ERC1155.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {LibString} from "solady/utils/LibString.sol";
import {IDepositContract} from "../interfaces/IDepositContract.sol";
import {IOptimisticWithdrawalRecipient} from "../interfaces/IOptimisticWithdrawalRecipient.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IERC165, IERC1155Receiver} from "src/interfaces/IERC1155Receiver.sol";
import {ISplitMain, SplitConfiguration} from "src/interfaces/ISplitMain.sol";
import {ISplitWallet} from "src/interfaces/ISplitWallet.sol";

/// @notice OWR principal recipient
/// @dev handles rewards and principal of OWR
contract ObolErc1155Recipient is ERC1155, Ownable, IERC1155Receiver {
  using SafeTransferLib for address;

  uint256 public lastId;

  // BeaconChain deposit contract
  IDepositContract public immutable depositContract;

  struct TokenInfo {
    address owr;
    address rewardAddress;
    uint256 claimable;

    uint256 maxSupply;
    address receiver;
  }

  struct DepositInfo {
    bytes pubkey;
    bytes withdrawal_credentials;
    bytes sig;
    bytes32 root;
  }

  mapping(uint256 id => TokenInfo) public tokenInfo;
  mapping(address owr => uint256) public owrTokens;

  mapping(uint256 id => uint256) public totalSupply;
  uint256 public totalSupplyAll;

  string private _baseUri;
  address private constant ETH_TOKEN_ADDRESS = address(0x0);
  uint256 private constant ETH_DEPOSIT_AMOUNT = 32 ether;
  uint256 private constant MIN_ETH_EXIT_AMOUNT = 16 ether;

  error LengthMismatch();
  error InvalidTokenAmount();
  error InvalidOwner();
  error InvalidOWR();
  error ClaimFailed();
  error InvalidLastSupply();
  error TransferFailed();
  error InvalidBurnAmount(uint256 necessary, uint received);

  constructor(string memory baseUri_, address _owner, address _depositContract) {
    lastId = 1;
    _baseUri = baseUri_;
    depositContract = IDepositContract(_depositContract);

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

  /// @dev Returns true if `msg.sender` is the receiver of id
  function isReceiverOf(uint256 id) public view returns (bool) {
    return tokenInfo[id].receiver == msg.sender;
  }

  /// @dev Returns max supply for id
  function getMaxSupply(uint256 id) public view returns (uint256) {
    return tokenInfo[id].maxSupply;
  }

  /// -----------------------------------------------------------------------
  /// functions - public & external
  /// -----------------------------------------------------------------------
  /// @notice triggers `OWR.distributeFunds`
  /// @dev callable by the receiver
  /// @param owr the OWR address
  function receiveRewards(address owr, SplitConfiguration calldata _splitConfig) external {
    uint256 _tokenId = owrTokens[owr];

    // check if sender is the receiver of id
    if (!isReceiverOf(_tokenId)) revert InvalidOwner();

    // call .distribute() on OWR
    uint256 balanceBefore = _getOWRTokenBalance(owr);
    IOptimisticWithdrawalRecipient(owr).distributeFunds();
    _distributeSplitsRewards(owr, _splitConfig);
    uint256 balanceAfter = _getOWRTokenBalance(owr);

    tokenInfo[_tokenId].claimable += (balanceAfter - balanceBefore);
  }

  function _distributeSplitsRewards(address owr, SplitConfiguration calldata _splitConfig) private {
    (,address _split,) = IOptimisticWithdrawalRecipient(owr).getTranches();
    address _splitMain = ISplitWallet(_split).splitMain();
    address _token = IOptimisticWithdrawalRecipient(owr).token();

    if (_token == address(0)) {
      ISplitMain(_splitMain).distributeETH(_split, _splitConfig.accounts, _splitConfig.percentAllocations, _splitConfig.distributorFee, _splitConfig.controller);
      ISplitMain(_splitMain).withdraw(address(this), 1, new ERC20[](0));
    } else {
      ISplitMain(_splitMain).distributeERC20(_split, ERC20(_token), _splitConfig.accounts, _splitConfig.percentAllocations, _splitConfig.distributorFee, _splitConfig.controller);

      ERC20[] memory tokens = new ERC20[](1);
      tokens[0] = ERC20(_token);
      ISplitMain(_splitMain).withdraw(address(this), 0, tokens);
    }

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
  /// @dev tokens are minted to address(this) and transferred when ETH is deposited to the DepositContract 
  /// @param to address registered as the tokens receiver
  /// @param maxSupply the max allowed amount for `lastId`
  /// @param owr OptimisticWithdrawalRecipient address
  /// @param rewardAddress rewards receiver address
  /// @return mintedId id of the minted NFT
  function mint(address to, uint256 maxSupply, address owr, address rewardAddress)
    external
    payable
    onlyOwner
    returns (uint256 mintedId)
  {
    // validation
    if (maxSupply == 0) revert InvalidTokenAmount();

    // mint
    mintedId = _assignInfoAndExtractId(owr, rewardAddress, to, maxSupply);
    _mint(address(this), mintedId, maxSupply, "");
  }

  /// @notice mints a batch of tokens
  /// @dev tokens are minted to address(this) and transferred when ETH is deposited to the DepositContract 
  /// @param to receiver address
  /// @param count batch length
  /// @param maxSupply the max allowed amounts for each id
  /// @param owrs OptimisticWithdrawalRecipient addresses
  /// @param rewardAddresses rewards receiver addresses
  /// @return mintedIds id list of the minted NFTs
  function mintBatch(
    address to,
    uint256 count,
    uint256[] calldata maxSupply,
    address[] calldata owrs,
    address[] calldata rewardAddresses
  ) external payable onlyOwner returns (uint256[] memory mintedIds) {
    // validate
    if (count != maxSupply.length) revert LengthMismatch();
    if (count != owrs.length) revert LengthMismatch();
    if (count != rewardAddresses.length) revert LengthMismatch();

    // mint up to `count`
    mintedIds = new uint256[](count);
    for (uint256 i; i < count; i++) {
      if (maxSupply[i] == 0) revert InvalidTokenAmount();
      mintedIds[i] = _assignInfoAndExtractId(owrs[i], rewardAddresses[i], to, maxSupply[i]);
      _mint(address(this), mintedIds[i], maxSupply[i], "");
    }
  }

  /// @notice deposits ETH to `DepositContract` and activates part of supply
  /// @param id token id
  /// @param count amount of supply to activate
  /// @param depositInfo deposit data needed for `DepositContract`
  function depositForToken(uint256 id, uint256 count, DepositInfo[] calldata depositInfo) external payable {
    // vaidate
    if (!isReceiverOf(id)) revert InvalidOwner();

    if (depositInfo.length != count) revert LengthMismatch();

    uint256 crtActiveSupply =totalSupply[id];
    
    if (crtActiveSupply + count > getMaxSupply(id)) revert InvalidLastSupply();

    if (msg.value < count * ETH_DEPOSIT_AMOUNT) revert InvalidTokenAmount();

    // deposit to ETH `DepositContract`
    for (uint i; i < count; i++) {
      depositContract.deposit{value: ETH_DEPOSIT_AMOUNT}(
        depositInfo[i].pubkey, depositInfo[i].withdrawal_credentials, depositInfo[i].sig, depositInfo[i].root 
      );
    }

    (bool success,) = address(this).call(abi.encodeWithSelector(this.safeTransferFrom.selector, tokenInfo[id].receiver, id, count, "0x"));
    if (!success) revert TransferFailed();

    // increase total supply
    totalSupply[id] += count;
    totalSupplyAll += count;
  }

  /// @notice increases maxSupply for token id
  /// @param id token id
  /// @param amount newly added supply
  function mintSupply(uint256 id, uint256 amount) external {
    // validate
    if (!isReceiverOf(id)) revert InvalidOwner();
    if (lastId < id) revert InvalidLastSupply();

    // mint for existing id
    _mint(address(this), id, amount, "");

    // increase supply
    tokenInfo[id].maxSupply += amount;
  }

  /// @notice decreases totalSupply for token id
  /// @param id token id
  /// @param amount newly removed supply
  function burn(uint256 id, uint256 amount) external {
    // validate
    if (!isReceiverOf(id)) revert InvalidOwner();
    if (amount == 0) revert InvalidTokenAmount();

    uint256 minEthAmount = MIN_ETH_EXIT_AMOUNT  * amount;
    uint256 ethBalanceBefore = address(this).balance;
    IOptimisticWithdrawalRecipient(tokenInfo[id].owr).distributeFunds();
    uint256 ethBalanceAfter = address(this).balance;
    uint256 ethReceived = ethBalanceAfter - ethBalanceBefore;

    if(ethReceived < minEthAmount) revert InvalidBurnAmount(minEthAmount, ethReceived);

    _burn(msg.sender, id, amount);

    totalSupply[id] -= amount;
    totalSupplyAll -= amount;

    (bool sent,) = tokenInfo[id].receiver.call{value: ethReceived}("");
    if (!sent) revert TransferFailed();
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

  function _assignInfoAndExtractId(address owr, address rewardAddress, address receiver, uint256 maxSupply) private returns (uint256 mintedId) {
    mintedId = _incrementId();

    TokenInfo memory info = TokenInfo({maxSupply: maxSupply, receiver: receiver, claimable: 0, owr: owr, rewardAddress: rewardAddress});
    tokenInfo[mintedId] = info;
    owrTokens[info.owr] = mintedId;
  }

  /// -----------------------------------------------------------------------
  /// IERC1155Receiver
  /// -----------------------------------------------------------------------
  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, IERC165) returns (bool) {
      return interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
  }
  function onERC1155Received(
      address,
      address,
      uint256,
      uint256,
      bytes memory
  ) public virtual override returns (bytes4) {
      return this.onERC1155Received.selector;
  }

  function onERC1155BatchReceived(
      address,
      address,
      uint256[] memory,
      uint256[] memory,
      bytes memory
  ) public virtual override returns (bytes4) {
      return this.onERC1155BatchReceived.selector;
  }
}
