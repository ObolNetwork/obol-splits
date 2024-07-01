// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {
  IEigenPod,
  IDelegationManager,
  IEigenPodManager,
  IEigenLayerUtils,
  IDelayedWithdrawalRouter
} from "src/interfaces/external/IEigenLayer.sol";

abstract contract EigenLayerTestBase is Test {
  address public constant ETH_ADDRESS = address(0);

  uint256 public constant PERCENTAGE_SCALE = 1e5;

  address public constant SPLIT_MAIN_GOERLI = 0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE;

  address public constant ENS_REVERSE_REGISTRAR_GOERLI = 0x084b1c3C81545d370f3634392De611CaaBFf8148;

  address public constant DEPOSIT_CONTRACT_GOERLI = 0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b;
  address public constant DELEGATION_MANAGER_GOERLI = 0x1b7b8F6b258f95Cf9596EabB9aa18B62940Eb0a8;
  address public constant POD_MANAGER_GOERLI = 0xa286b84C96aF280a49Fe1F40B9627C2A2827df41;
  address public constant DELAY_ROUTER_GOERLI = 0x89581561f1F98584F88b0d57c2180fb89225388f;
  // eigenlayer admin
  address public constant DELAY_ROUTER_OWNER_GOERLI = 0x37bAFb55BC02056c5fD891DFa503ee84a97d89bF;
  address public constant EIGEN_LAYER_OPERATOR_GOERLI = 0x3DeD1CB5E25FE3eC9811B918A809A371A4965A5D;

  uint256 internal constant BALANCE_CLASSIFICATION_THRESHOLD = 16 ether;

  function encodeEigenPodCall(address recipient, uint256 amount) internal pure returns (bytes memory callData) {
    callData = abi.encodeCall(IEigenPod.withdrawNonBeaconChainETHBalanceWei, (recipient, amount));
  }

  function encodeDelegationManagerCall(address operator) internal pure returns (bytes memory callData) {
    IEigenLayerUtils.SignatureWithExpiry memory signature = IEigenLayerUtils.SignatureWithExpiry(bytes(""), 0);
    callData = abi.encodeCall(IDelegationManager.delegateTo, (operator, signature, bytes32(0)));
  }

  function encodeEigenPodManagerCall(uint256) internal pure returns (bytes memory callData) {
    bytes memory pubkey = bytes("");
    bytes memory signature = bytes("");
    bytes32 dataRoot = bytes32(0);

    callData = abi.encodeCall(IEigenPodManager.stake, (pubkey, signature, dataRoot));
  }

  function _min(uint256 a, uint256 b) internal pure returns (uint256 min) {
    min = a > b ? b : a;
  }

  function _max(uint256 a, uint256 b) internal pure returns (uint256 max) {
    max = a > b ? a : b;
  }
}
