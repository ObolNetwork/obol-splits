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
import {IPullSplit} from "src/interfaces/IPullSplit.sol";
import {ISplitsWarehouse} from "src/interfaces/ISplitsWarehouse.sol";

/// @notice OWR principal recipient
/// @dev handles rewards and principal of OWR
contract ObolErc1155Recipient is ERC1155, Ownable, IERC1155Receiver {
  using SafeTransferLib for address;

  struct DepositInfo {
    bytes pubkey;
    bytes withdrawal_credentials;
    bytes sig;
    bytes32 root;
  }

  struct Partition {
    uint256 maxSupply;
    address owr;
    address operator;
  }

  uint256 public lastId;
  uint256 public partitionCount;
  mapping(uint256 _partitionId => Partition) public partitions;
  mapping(uint256 _partitionId => uint256[] _tokenIds) public partitionTokens;
  mapping(address _owr => uint256 _partitionId) public owrsPartition;

  mapping(uint256 _tokenId => uint256 _partitionId) public tokensPartition;
  mapping(uint256 _tokenId => address _owner) public ownerOf;

  mapping(address _owner => uint256 _amount) public claimable;

  mapping(uint256 id => uint256) public totalSupply;
  uint256 public totalSupplyAll;

  // BeaconChain deposit contract
  IDepositContract public immutable depositContract;

  string private _baseUri;
  address private constant ETH_TOKEN_ADDRESS = address(0x0);
  uint256 private constant ETH_DEPOSIT_AMOUNT = 32 ether;
  uint256 private constant MIN_ETH_EXIT_AMOUNT = 16 ether;

  error PartitionSupplyReached();
  error DepositAmountNotValid();
  error PartitionNotValid();
  error OwrNotValid();

  error LengthMismatch();
  error InvalidTokenAmount();
  error InvalidOwner();
  error InvalidOWR();
  error ClaimFailed();
  error InvalidLastSupply();
  error TransferFailed();
  error InvalidBurnAmount(uint256 necessary, uint256 received);

  event PartitionCreated(address indexed _owr, uint256 indexed _partitionId, uint256 indexed _maxSupply);
  event Minted(uint256 indexed _partitionId, uint256 indexed _mintedId, address indexed _sender);

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
  function isOwnerOf(uint256 _tokenId) public view returns (bool) {
    return balanceOf(msg.sender, _tokenId) > 0;
  }

  /// @dev Returns max supply for id
  function getMaxSupply(uint256 _tokenId) public view returns (uint256) {
    uint256 _partition = tokensPartition[_tokenId];
    return partitions[_partition].maxSupply;
  }

  /// -----------------------------------------------------------------------
  /// functions - public & external
  /// -----------------------------------------------------------------------

  /// @notice creates a new partition
  /// @dev TODO: TBD DOS risk
  /// @param maxSupply the maximum number of unique tokens
  /// @param owr the Optimistic Withdrawal Recipient address
  function createPartition(uint256 maxSupply, address owr) external {
    uint256 _id = partitionCount;
    partitions[_id] = Partition({maxSupply: maxSupply, owr: owr, operator: msg.sender});
    owrsPartition[owr] = _id;

    partitionCount++;
    emit PartitionCreated(owr, _id, maxSupply);
  }

  /// @notice mints a new token and deposits to ETH deposit contract
  /// @param _partitionId the partition to assign it to
  /// @param depositInfo deposit data needed for `DepositContract`
  /// @return mintedId id of the minted NFT
  function mint(uint256 _partitionId, DepositInfo calldata depositInfo) external payable returns (uint256 mintedId) {
    // validation
    if (partitions[_partitionId].owr == address(0)) revert PartitionNotValid();
    if (partitionTokens[_partitionId].length + 1 > partitions[_partitionId].maxSupply) revert PartitionSupplyReached();
    if (msg.value != ETH_DEPOSIT_AMOUNT) revert DepositAmountNotValid();

    // retrieve id
    mintedId = _incrementId();

    // add partition details
    partitionTokens[_partitionId].push(mintedId);
    tokensPartition[mintedId] = _partitionId;

    // increase total supply
    totalSupply[mintedId]++;
    totalSupplyAll++;

    // deposit to ETH deposit contract
    depositContract.deposit{value: ETH_DEPOSIT_AMOUNT}(
      depositInfo.pubkey, depositInfo.withdrawal_credentials, depositInfo.sig, depositInfo.root
    );

    // mint to sender
    _mint(msg.sender, mintedId, 1, "");
    ownerOf[mintedId] = msg.sender;

    emit Minted(_partitionId, mintedId, msg.sender);
  }

  /// @notice decreases totalSupply for token id
  /// @param _tokenId token id
  function burn(uint256 _tokenId) external {
    // validate
    if (!isOwnerOf(_tokenId)) revert InvalidOwner();

    // retrieve OWR
    address _owr = partitions[tokensPartition[_tokenId]].owr;
    if (_owr == address(0)) revert OwrNotValid();

    uint256 ethBalanceBefore = address(this).balance;
    IOptimisticWithdrawalRecipient(_owr).distributeFunds();
    uint256 ethBalanceAfter = address(this).balance;
    uint256 ethReceived = ethBalanceAfter - ethBalanceBefore;
    // TODO: check `ethReceived` amount

    if (ethReceived < MIN_ETH_EXIT_AMOUNT) revert InvalidBurnAmount(MIN_ETH_EXIT_AMOUNT, ethReceived);

    _burn(msg.sender, _tokenId, 1);

    totalSupply[_tokenId]--;
    totalSupplyAll--;

    (bool sent,) = msg.sender.call{value: ethReceived}("");
    if (!sent) revert TransferFailed();
  }

  /// @notice triggers `OWR.distributeFunds` and updates claimable balances for partition
  /// @param _tokenId token id
  /// @param _splitConfig pull split configuration
  function distributeRewards(
    uint256 _tokenId,
    address _distributor,
    IPullSplit.PullSplitConfiguration calldata _splitConfig
  ) external {
    uint256 _partitionId = tokensPartition[_tokenId];
    address _owr = partitions[tokensPartition[_tokenId]].owr;
    if (_owr == address(0)) revert OwrNotValid();

    // call .distribute() on OWR
    uint256 balanceBefore = _getTokenBalance(_owr);
    IOptimisticWithdrawalRecipient(_owr).distributeFunds();
    _distributeSplitsRewards(_owr, _distributor, _splitConfig);
    uint256 balanceAfter = _getTokenBalance(_owr);

    uint256 _totalClaimable = balanceAfter - balanceBefore;
    if (_totalClaimable > 0) {
      uint256 count = partitionTokens[_partitionId].length;
      uint256 _reward = _totalClaimable / count;
      for (uint256 i; i < count; i++) {
        address _owner = ownerOf[partitionTokens[_partitionId][i]];
        claimable[_owner] += _reward;
      }
    }
  }

  /// @notice claim rewards
  function claim(address _user) external {
    if (claimable[_user] > 0) {
      (bool sent,) = _user.call{value: claimable[_user]}("");
      if (!sent) revert TransferFailed();
    }
    claimable[_user] = 0;
  }

  /// -----------------------------------------------------------------------
  /// functions - private
  /// -----------------------------------------------------------------------

  //TODO: refactor this
  function _distributeSplitsRewards(
    address owr,
    address _distributor,
    IPullSplit.PullSplitConfiguration calldata _splitConfig
  ) private {
    (, address _split,) = IOptimisticWithdrawalRecipient(owr).getTranches();
    address _token = IOptimisticWithdrawalRecipient(owr).token();

    IPullSplit(_split).distribute(_splitConfig, _token, _distributor);
    address warehouse = IPullSplit(_split).SPLITS_WAREHOUSE();
    ISplitsWarehouse(warehouse).withdraw(address(this), _token);
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
      ownerOf[ids[i]] = to;
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

  function _getTokenBalance(address owr) private view returns (uint256 balance) {
    address token = IOptimisticWithdrawalRecipient(owr).token();
    if (token == ETH_TOKEN_ADDRESS) balance = address(this).balance;
    else balance = ERC20(token).balanceOf(address(this));
  }

  /// -----------------------------------------------------------------------
  /// IERC1155Receiver
  /// -----------------------------------------------------------------------
  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, IERC165) returns (bool) {
    return interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
  }

  function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual override returns (bytes4) {
    return this.onERC1155Received.selector;
  }

  function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory)
    public
    virtual
    override
    returns (bytes4)
  {
    return this.onERC1155BatchReceived.selector;
  }
}
