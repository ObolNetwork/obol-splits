// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {ObolRocketPoolRecipientFactory} from "src/rocket-pool/ObolRocketPoolRecipientFactory.sol";
import {RPMinipoolManagerMock} from "src/test/rocket-pool/mocks/RPMinipoolManagerMock.sol";
import {RPMinipoolMock} from "src/test/rocket-pool/mocks/RPMinipoolMock.sol";
import {RPStorageMock} from "src/test/rocket-pool/mocks/RPStorageMock.sol";

contract RocketPoolRecipientFactoryScript is Script {
  uint256 constant ETH_STAKE_THRESHOLD = 16 ether;
  uint256 constant GNO_STAKE_THRESHOLD = 0.8 ether;

  function run(string memory _name, address _ensReverseRegistrar, address _ensOwner, bool _test) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");

    vm.startBroadcast(privKey);

    address rpStorage;
    if (_test) {
        // deploy mock minipool manager
        new RPMinipoolManagerMock{salt: keccak256("obol.RPMinipoolManagerMock.v1.0")}();

        // deploy mock minipool
        new RPMinipoolMock{salt: keccak256("obol.RPMinipoolMock.v1.0")}();

        // deploy mock storage
        rpStorage = address(new RPStorageMock{salt: keccak256("obol.RPStorageMock.v1.0")}());
    } else {
        rpStorage = vm.envAddress("ROCKET_POOL_STORAGE");
    }

    new ObolRocketPoolRecipientFactory{salt: keccak256("obol.rocketPoolRecipientFactoryWithToken.v1.0")}(
      rpStorage, _name, _ensReverseRegistrar, _ensOwner
    );


    vm.stopBroadcast();
  }
}
