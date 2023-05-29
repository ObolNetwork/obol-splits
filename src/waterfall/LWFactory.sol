// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {LibClone} from "solady/utils/LibClone.sol";
import {WalletCloneImpl} from "./wallet/WalletCloneImpl.sol";
import {LW1155CloneImpl} from "./token/LW1155CloneImpl.sol";
import {IWaterfallFactoryModule} from "../interfaces/IWaterfallFactoryModule.sol";

contract LWFactory {
  using LibClone for address;

  /// @dev wallet implementation
  WalletCloneImpl public immutable walletImpl;

  /// @dev liquid waterfall implementation
  LW1155CloneImpl public immutable lw1155ClonefallImpl;

  /// @dev waterfall factory
  IWaterfallFactoryModule public immutable waterfallFactoryModule;

  constructor(IWaterfallFactoryModule _waterfallFactoryModule) {
    walletImpl = new WalletCloneImpl();
    lw1155ClonefallImpl = new LW1155CloneImpl();
    waterfallFactoryModule = _waterfallFactoryModule;
  }

  /// Create a new WaterfallModule clone
  /// @param _token Address of ERC20 to waterfall (0x0 used for ETH)
  /// @param _nonWaterfallRecipient Address to recover non-waterfall tokens to
  /// @param _recipients Addresses to waterfall payments to
  /// @param _thresholds Absolute payment thresholds for waterfall recipients
  /// (last recipient has no threshold & receives all residual flows)
  /// @return liquidWaterfall Address of new WaterfallModule clone
  function createLiquidWaterfall(
    address _token,
    address _nonWaterfallRecipient,
    address[] calldata _recipients,
    uint256[] calldata _thresholds,
    bytes calldata _salt
  ) external returns (address liquidWaterfall, address waterfall, address[] memory wallets) {
    bytes32 liquidWaterfallSalt = keccak256(_salt);

    liquidWaterfall = _deployLiquidWaterfall(liquidWaterfallSalt, _recipients);

    // deploy wallet
    wallets = new address[](_recipients.length);
    for (uint256 i = 0; i < _recipients.length; i++) {
      wallets[i] = _createWallet(liquidWaterfall, i);
    }

    // deploy waterfall
    waterfall = waterfallFactoryModule.createWaterfallModule(_token, _nonWaterfallRecipient, wallets, _thresholds);
  }

  function _deployLiquidWaterfall(bytes32 salt, address[] calldata accounts) internal returns (address liquidWaterfall) {
    liquidWaterfall = address(lw1155ClonefallImpl).cloneDeterministic(salt);
    // intialize
    LW1155CloneImpl(liquidWaterfall).initialize(accounts);
  }

  function _createWallet(address liquidWaterfall, uint256 tokenId) internal returns (address wallet) {
    bytes memory data = abi.encodePacked(liquidWaterfall, tokenId);
    wallet = address(walletImpl).clone(data);
  }
}
