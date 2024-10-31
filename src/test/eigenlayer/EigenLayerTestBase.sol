// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {
  IEigenPod,
  IDelegationManager,
  IEigenPodManager,
  IEigenLayerUtils,
  IDelayedWithdrawalRouter
} from "src/interfaces/IEigenLayer.sol";

abstract contract EigenLayerTestBase is Test {
  address public constant ETH_ADDRESS = address(0);

  uint256 public constant PERCENTAGE_SCALE = 1e5;

  address internal SPLIT_MAIN_HOLESKY = 0xfC8a305728051367797DADE6Aa0344E0987f5286;

  address public constant ENS_REVERSE_REGISTRAR_HOLESKY = 0x132AC0B116a73add4225029D1951A9A707Ef673f;

  address public constant DEPOSIT_CONTRACT_HOLESKY = 0x4242424242424242424242424242424242424242;

  address public constant DELEGATION_MANAGER_HOLESKY = 0xA44151489861Fe9e3055d95adC98FbD462B948e7;
  address public constant POD_MANAGER_HOLESKY = 0x30770d7E3e71112d7A6b7259542D1f680a70e315;
  address public constant DELAY_ROUTER_HOLESKY = 0x642c646053eaf2254f088e9019ACD73d9AE0FA32;
  // eigenlayer admin
  address public constant DELAY_ROUTER_OWNER_HOLESKY = 0x28Ade60640fdBDb2609D8d8734D1b5cBeFc0C348 ;
  // 
  address public constant EIGEN_LAYER_OPERATOR_HOLESKY = 0x543533E83A78950042BD59fF7822f39F440E9E6b ;

  uint256 internal constant BALANCE_CLASSIFICATION_THRESHOLD = 16 ether;

  function encodeEigenPodCall(address recipient, uint256 amount) internal pure returns (bytes memory callData) {
    callData = abi.encodeCall(IEigenPod.withdrawRestakedBeaconChainETH, (recipient, amount));
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
