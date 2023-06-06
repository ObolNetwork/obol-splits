// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "solady/auth/Ownable.sol";
import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {LibString} from "solmate/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {TokenUtils} from "splits-utils/TokenUtils.sol";
import {utils} from "../../lib/Utils.sol";
import {Renderer} from "../../lib/Renderer.sol";
import {ISplitMain, SplitConfiguration} from "../../interfaces/ISplitMain.sol";
import {IWaterfallModule} from "../../interfaces/IWaterfallModule.sol";

// @title LW1155
/// @author Obol
/// @notice A minimal liquid waterfall and splits implementation
/// Ownership is represented by 1155s (each = 100% of waterfall tranche + split)
contract LW1155 is ERC1155, Ownable {

  /// @dev invalid owner
  error InvalidOwner();
  /// @dev zero address
  error InvalidAddress();
  /// @dev zero number
  error ZeroAmount();
  /// @dev claim exists
  error ClaimExists();

  /// -----------------------------------------------------------------------
  /// libraries
  /// -----------------------------------------------------------------------
  using TokenUtils for address;

  /// -----------------------------------------------------------------------
  /// events
  /// -----------------------------------------------------------------------
  event ReceiveETH(address indexed sender, uint256 amount);
  event Recovered(address sender, address token, uint256 amount);

  /// -----------------------------------------------------------------------
  /// structs
  /// -----------------------------------------------------------------------
  struct Claim {
    ISplitMain split;
    IWaterfallModule waterfall;
    SplitConfiguration configuration;
  }

  /// -----------------------------------------------------------------------
  /// storage
  /// -----------------------------------------------------------------------
  /// @dev ETH address representation
  address internal constant ETH_TOKEN_ADDRESS = address(0x0);
  /// @dev splitMain factory
  ISplitMain public immutable splitMain;
  /// @dev obol treasury
  address public immutable recoveryWallet;

  /// -----------------------------------------------------------------------
  /// storage - mutables
  /// -----------------------------------------------------------------------

  /// @dev nft claim information
  mapping(uint256 => Claim) public claimData;

  constructor(ISplitMain _splitMain, address _recoveryWallet) {
    if (_recoveryWallet == address(0)) {
      revert InvalidAddress();
    }
    
    splitMain = _splitMain;
    recoveryWallet = _recoveryWallet;
    _initializeOwner(msg.sender);
  }

  /// @dev Mint NFT
  /// @param _recipient address to receive minted NFT
  /// @param _configuration split configuration
  function mint(address _recipient, address _split, address _waterfall, SplitConfiguration calldata _configuration)
    external
    onlyOwner
  {
    // waterfall is unique per validator
    uint256 id = uint256(keccak256(abi.encodePacked(_recipient, _waterfall)));
    Claim memory claiminfo = Claim(ISplitMain(_split), IWaterfallModule(_waterfall), _configuration);

    if (address(claimData[id].split) != address(0)) {
      revert ClaimExists();
    }

    claimData[id] = claiminfo;
    _mint({to: _recipient, id: id, amount: 1, data: ""});
  }

  /// @dev send tokens and ETH to receiver
  /// @notice Ensures the receiver is the right address to receive the tokens
  /// @param _tokenIds address of tokens, address(0) represents ETH
  /// @param _receiver address holding the NFT
  function claim(uint256[] calldata _tokenIds, address _receiver) external {
    uint256 size = _tokenIds.length;

    for (uint256 i = 0; i < size;) {
      uint256 tokenId = _tokenIds[i];

      if (balanceOf[_receiver][tokenId] == 0) revert InvalidOwner();

      // fetch claim information
      Claim memory tokenClaim = claimData[tokenId];

      // claim from waterfall
      tokenClaim.waterfall.waterfallFunds();

      // claim from splitter
      splitMain.distributeETH(
        address(tokenClaim.split),
        tokenClaim.configuration.accounts,
        tokenClaim.configuration.percentAllocations,
        tokenClaim.configuration.distributorFee,
        address(0)
      );
      ERC20[] memory emptyTokens = new ERC20[](0);
      splitMain.withdraw(address(this), 1, emptyTokens);

      // transfer claimed eth to receiver
      ETH_TOKEN_ADDRESS._safeTransfer(_receiver, ETH_TOKEN_ADDRESS._balanceOf(address(this)));

      unchecked {
        ++i;
      }
    }
  }
  
  /// Transfers a given `_amount` of an ERC20-token where address(0) is ETH
  /// @param _token an ERC20-compatible token
  /// @param _amount token amount
  function recover(ERC20 _token, uint256 _amount) external {
    if (_amount == 0) {
      revert ZeroAmount();
    }

    emit Recovered(msg.sender, address(_token), _amount);

    address(_token)._safeTransfer(recoveryWallet, _amount);
  }

  /// @dev Returns token uri
  function uri(uint256) public view override returns (string memory) {
    return string.concat(
      "data:application/json;base64,",
      Base64.encode(
        bytes(
          string.concat(
            '{"name": "Obol Liquid Waterfall + Split ',
            utils.shortAddressToString(address(this)),
            '", "description": ',
            '"Each token represents 32 ETH staked plus rewards", ',
            '"external_url": ',
            '"https://app.0xsplits.xyz/accounts/',
            utils.addressToString(address(this)),
            "/?chainId=",
            utils.uint2str(block.chainid),
            '", ',
            '"image": "data:image/svg+xml;base64,',
            Base64.encode(bytes(Renderer.render(address(this)))),
            '"}'
          )
        )
      )
    );
  }

  /// @dev Returns ERC1155 name
  function name() external view returns (string memory) {
    return string.concat("Obol Liquid Waterfall + Split ", utils.shortAddressToString(address(this)));
  }

  /// @dev Enables ERC1155 to receive ETH
  receive() external payable {
    emit ReceiveETH(msg.sender, msg.value);
  }
}
