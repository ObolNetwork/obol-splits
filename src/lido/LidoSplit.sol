// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Clone} from "solady/utils/Clone.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {INodeOperatorRegistry} from "src/interfaces/lido/INodeOperatorRegistry.sol";
import {IEasyTrackMotion} from "src/interfaces/lido/IEasyTrackMotion.sol";

interface IwSTETH {
  function wrap(uint256 amount) external returns (uint256);
}

/// @title LidoSplit
/// @author Obol
/// @notice A wrapper for 0xsplits/split-contracts SplitWallet that transforms
/// stETH token to wstETH token because stETH is a rebasing token
/// @dev Wraps stETH to wstETH and transfers to defined SplitWallet address
contract LidoSplit is Clone, Ownable {
  error Invalid_Address();

  /// @notice Call
  struct Call {
    address target;
    bytes callData;
  }

  /// -----------------------------------------------------------------------
  /// libraries
  /// -----------------------------------------------------------------------
  using SafeTransferLib for ERC20;
  using SafeTransferLib for address;

  address internal constant ETH_ADDRESS = address(0);

  /// -----------------------------------------------------------------------
  /// storage - cwia offsets
  /// -----------------------------------------------------------------------

  // splitWallet (adress, 20 bytes)
  // 0; first item
  uint256 internal constant SPLIT_WALLET_ADDRESS_OFFSET = 0;

  /// -----------------------------------------------------------------------
  /// storage
  /// -----------------------------------------------------------------------

  /// @notice stETH token
  ERC20 public immutable stETH;

  /// @notice wstETH token
  ERC20 public immutable wstETH;

  /// @notice node operator registry
  INodeOperatorRegistry public immutable nosRegistry;

  /// @notice Easy track motion contract
  IEasyTrackMotion public immutable easyTrackMotion;

  constructor(ERC20 _stETH, ERC20 _wstETH, address _nosRegistry, IEasyTrackMotion _etMotion) {
    stETH = _stETH;
    wstETH = _wstETH;
    nosRegistry = _INodeOperatorRegistry(_nosRegistry);
    easyTrackMotion = _etMotion;
  }

  function intialize(address _owner) external {
    if (owner() != address(0)) revert Initialized();

    _initializeOwner(_owner);
  }

  /// Address of split wallet to send funds to to
  /// @dev equivalent to address public immutable splitWallet
  function splitWallet() public pure returns (address) {
    return _getArgAddress(SPLIT_WALLET_ADDRESS_OFFSET);
  }

  /// Wraps the current stETH token balance to wstETH
  /// transfers the wstETH balance to splitWallet for distribution
  /// @return amount Amount of wstETH transferred to splitWallet
  function distribute() external returns (uint256 amount) {
    // get current balance
    uint256 balance = stETH.balanceOf(address(this));
    // approve the wstETH
    stETH.approve(address(wstETH), balance);
    // wrap into wseth
    amount = IwSTETH(address(wstETH)).wrap(balance);
    // transfer to split wallet
    ERC20(wstETH).safeTransfer(splitWallet(), amount);
  }

  /// @notice Add node operator signing keys
  /// @param _nodeOperatorId Node Operator id
  /// @param _keysCount Number of signing keys provided
  /// @param _publicKeys Several concatenated validator signing keys
  /// @param _signatures Several concatenated signatures for (pubkey, withdrawal_credentials, 32000000000) messages
  function addSigningKeys(
    uint256 _nodeOperatorId,
    uint256 _keysCount,
    bytes calldata _publicKeys,
    bytes calldata _signatures
  ) external onlyOwner {
    nos.addSigningKeys(_nodeOperatorId, _keysCount, _publicKeys, _signatures);
  }

  /// @notice Removes node operator signing keys
  /// @param _nodeOperatorId Node Operator id
  /// @param _keysCount Number of signing keys provided
  /// @param _publicKeys Several concatenated validator signing keys
  /// @param _signatures Several concatenated signatures for (pubkey, withdrawal_credentials, 32000000000) messages
  function removeSigningKeys(uint256 _nodeOperatorId, uint256 _fromIndex, uint256 _keysCount) external onlyOwner {
    nos.removeSigningKeys(_nodeOperatorId, _fromIndex, _keysCount);
  }

  /// @notice Create easy track motions
  /// @param _evmScriptFactory Address of EVMScript factory registered in Easy Track
  /// @param _evmScriptCallData Encoded call data of EVMScript factory
  /// @return _newMotionId Id of created motion
  function createEasyTrackMotion(address _evmScriptFactory, bytes calldata _evmScriptCallData)
    external
    onlyOwner
    returns (uint256 newMotionId)
  {
    newMotionId = easyTrackMotion.createMotion(_evmScriptFactory, _evmScriptCallData);
  }

  /// @notice Rescue stuck ETH
  /// Uses token == address(0) to represent ETH
  /// @return balance Amount of ETH rescued
  function rescueFunds(address token) external returns (uint256 balance) {
    if (token == address(stETH)) revert Invalid_Address();

    if (token == ETH_ADDRESS) {
      balance = address(this).balance;
      if (balance > 0) splitWallet().safeTransferETH(balance);
    } else {
      balance = ERC20(token).balanceOf(address(this));
      if (balance > 0) ERC20(token).transfer(splitWallet(), balance);
    }
  }

  /// @notice Execute custom calls
  /// @param calls An array of Call structs
  /// @return blockNumber The block number where the calls were executed
  /// @return returnData An array of bytes containing the responses
  function executeCalls(Call[] calldata calls)
    public
    payable
    onlyOwner
    returns (uint256 blockNumber, bytes[] memory returnData)
  {
    blockNumber = block.number;
    uint256 length = calls.length;
    returnData = new bytes[](length);
    Call calldata call;
    for (uint256 i = 0; i < length;) {
      bool success;
      call = calls[i];
      (success, returnData[i]) = call.target.call(call.callData);
      require(success, "executeCalls: call failed");
      unchecked {
        ++i;
      }
    }
  }
}
