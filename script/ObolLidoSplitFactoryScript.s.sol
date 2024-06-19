// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {ObolLidoSplitFactory} from "src/lido/ObolLidoSplitFactory.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract ObolLidoSplitFactoryScript is Script {
  function run(address _feeRecipient, uint256 _feeShare, address _stETH, address _wstETH) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(privKey);

    ERC20 stETH = ERC20(_stETH);
    ERC20 wstETH = ERC20(_wstETH);

    new ObolLidoSplitFactory{salt: keccak256("obol.lidoSplitFactory.v1")}(_feeRecipient, _feeShare, stETH, wstETH);

    vm.stopBroadcast();
  }
}
