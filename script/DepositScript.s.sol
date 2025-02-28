// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ObolValidatorManager} from "src/ovm/ObolValidatorManager.sol";

//
// This script calls deposit() on a ObolValidatorManager contract.
// To run this script, the following environment variables must be set:
// - PRIVATE_KEY: the private key of the account that will deploy the contract
// Example usage:
//   forge script script/DepositScript.s.sol --sig "run(address,string)" -vvv \
//   --rpc-url https://rpc.pectra-devnet-5.ethpandaops.io/ --broadcast "<ovm_address>" "<deposit_file_path>"
//
contract DepositScript is Script {
  struct DepositData {
    // fields must be sorted alphabetically
    uint256 amount;
    string deposit_cli_version;
    string deposit_data_root;
    string deposit_message_root;
    string fork_version;
    string network_name;
    string pubkey;
    string signature;
    string withdrawal_credentials;
  }

  function run(address ovmAddress, string memory depositFilePath) external {
    uint256 privKey = vm.envUint("PRIVATE_KEY");

    console.log("Reading deposit data from file: %s", depositFilePath);

    string memory file = vm.readFile(depositFilePath);
    bytes memory parsedJson = vm.parseJson(file);
    DepositData[] memory depositDatas = abi.decode(parsedJson, (DepositData[]));

    console.log("Number of deposit records: %d", depositDatas.length);

    vm.startBroadcast(privKey);

    uint256 totalAmount;

    for (uint256 j = 0; j < depositDatas.length; j++) {
      DepositData memory depositData = depositDatas[j];

      console.log("Deposit at index %d for amount of %d ether:", j, depositData.amount / 1 gwei);
      console.log("  PK: %s", depositData.pubkey);
      console.log("  WC: %s", depositData.withdrawal_credentials);

      totalAmount += depositData.amount;
    }

    console.log("Total amount will be deposited: %d ether", totalAmount / 1 gwei);
    require(totalAmount > address(this).balance, "You don't have enough balance to deposit");

    ObolValidatorManager ovm = ObolValidatorManager(payable(ovmAddress));
    console.log("Currently staked amount: %d ether", ovm.amountOfPrincipalStake() / 1 ether);

    // Executing deposits...
    for (uint256 j = 0; j < depositDatas.length; j++) {
      DepositData memory depositData = depositDatas[j];

      console.log("Depositing %s for amount of %d ether", depositData.pubkey, depositData.amount / 1 gwei);

      bytes memory pubkey = vm.parseBytes(depositData.pubkey);
      bytes memory withdrawal_credentials = vm.parseBytes(depositData.withdrawal_credentials);
      bytes memory signature = vm.parseBytes(depositData.signature);
      bytes32 deposit_data_root = vm.parseBytes32(depositData.deposit_data_root);
      uint256 deposit_amount = depositData.amount * 1 gwei;
      ovm.deposit{value: deposit_amount}(pubkey, withdrawal_credentials, signature, deposit_data_root);

      console.log("Deposit successful for amount: %d ether", depositData.amount / 1 gwei);
    }

    console.log("All deposits executed successfully.");

    vm.stopBroadcast();
  }
}
