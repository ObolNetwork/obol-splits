# ObolValidatorManager scripts

## RPC Endpoints

You can use any RPC endpoint, but here are some public ones suitable for running these scripts:

- Mainnet: https://ethereum-rpc.publicnode.com
- Sepolia: https://ethereum-sepolia-rpc.publicnode.com
- Holesky: https://ethereum-holesky-rpc.publicnode.com
- Hoodi:   https://ethereum-hoodi-rpc.publicnode.com

Note: all the scripts and examples below are designed to run on the Sepolia network.
Use different RPC endpoints for other networks, as well as different OVM Factory addresses.

If you are experiencing issues while running the scripts, add `-vvv` to the command to enable verbose logging.

## DeployFactoryScript

You don't have to deploy a new factory unless you know what you are doing. Consider using factories [deployed by Obol](https://docs.obol.org/next/learn/readme/obol-splits#obol-validator-manager-factory-deployment).

This script deploys the `ObolValidatorManagerFactory` contract. To run this script, the following environment variables must be set:

- `PRIVATE_KEY`: the private key of the account that will deploy the contract

**Please verify the addresses in the script code before running the script!**

The script takes only one parameter: the deployment name, which is used by the deterministic deployer and for ENS lookup. Therefore, it must be unique per network.

Example usage:

```bash
# Make sure the last argument is a unique string identifying your own deployment
forge script script/ovm/DeployFactoryScript.s.sol --sig "run(string)" \
     --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast "OVMFactory.Sepolia"
```

In the console, watch for the output:

```
== Logs ==
  ObolValidatorManagerFactory deployed at 0x1764d3013f401289F9dbE42E7C703217a9D9D5C2
  Explorer URL for address https://sepolia.etherscan.io/address//0x1764d3013f401289F9dbE42E7C703217a9D9D5C2
```

### Getting Contracts Verified with Etherscan

If you deploy a contract for the first time, or if you deploy a patched version, then you may want to verify your code with the Etherscan UI.

1. Flatten the target contract code:

```bash
forge flatten src/ovm/ObolValidatorManagerFactory.sol --output ObolValidatorManagerFactory_flattened.sol
```

2. Go to Etherscan, open the "Contract" tab for a deployed contract instance, and click "Verify & Publish" using "Single solidity file" mode.
3. Use the flattened contract code as the input for verification.

## CreateOVMScript

This script calls the `createObolValidatorManager` function of the `ObolValidatorManagerFactory` contract to create a new instance of the `ObolValidatorManager` contract.

Script parameters:
- `ovmFactory`: The address of the deployed `ObolValidatorManagerFactory` contract.
- `owner`: The address of the owner of the new `ObolValidatorManager` contract.
- `principalRecipient`: The address of the principal recipient.
- `rewardsRecipient`: The address of the rewards recipient.
- `principalThreshold`: The principal threshold value (gwei), recommended value is `16000000000` (16 ether).

Example usage:

```bash
forge script script/ovm/CreateOVMScript.s.sol --sig "run(address,address,address,address,uint64)" \
    --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast \
    0x1764d3013f401289F9dbE42E7C703217a9D9D5C2 0x46aB8712c7A5423b717F648529B1c7A17099750A 0x46aB8712c7A5423b717F648529B1c7A17099750A 0x46aB8712c7A5423b717F648529B1c7A17099750A 16000000000
```

In the console, watch for the output:

```
== Logs ==
  ObolValidatorManager created at address 0x197d3c66a06FfD98F7316D71190EbD74262103b5
  Explorer URL for address https://sepolia.etherscan.io/address/0x197d3c66a06FfD98F7316D71190EbD74262103b5
```

## SystemContractFeesScript

The script simply prints the immediate fees for the two system contracts: consolidation & withdrawal.

Usage:

```bash
forge script script/ovm/SystemContractFeesScript.s.sol --rpc-url https://ethereum-sepolia-rpc.publicnode.com
```

In the console, you should see the fees printed out in WEI:

```
== Logs ==
  Consolidation Fee 1 WEI
  Withdrawal Fee 1 WEI
```

## GrantRoleScript

This script calls `grantRole()` for an ObolValidatorManager contract.

To run this script, the following environment variables must be set:
- `PRIVATE_KEY`: the private key of the account that will call the function

Script parameters:
- `ovmAddress`: The address of the deployed `ObolValidatorManager` contract.
- `account`: The address to grant the role to.
- `roles`: The roles to grant (bitwise OR).

```bash
#   SET_PRINCIPAL_ROLE = 0x04 | RECOVER_FUNDS_ROLE = 0x0C
forge script script/ovm/GrantRoleScript.s.sol --sig "run(address,address,uint256)" \
   --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast \
   0x197d3c66a06FfD98F7316D71190EbD74262103b5 0xE84E904936C595C55b9Ad08532d9aD0A5d76df72 0x0C
```

Typical output:

```
== Logs ==
   New roles for account 0x0C
```

## DistributeFundsScript

This script calls `distributeFunds()` for an ObolValidatorManager contract.

To run this script, the following environment variables must be set:
- `PRIVATE_KEY`: the private key of the account that will call the function

Script parameters:
- `ovmAddress`: The address of the deployed `ObolValidatorManager` contract.

```bash
forge script script/ovm/DistributeFundsScript.s.sol --sig "run(address)" \
   --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast 0x197d3c66a06FfD98F7316D71190EbD74262103b5
```

After executing the script, verify your principal and reward recipient balances.

## SetPrincipalRecipientScript

This script calls `setPrincipalRecipient()` for an ObolValidatorManager contract.

To run this script, the following environment variables must be set:
- `PRIVATE_KEY`: the private key of the account that will call the function

Script parameters:
- `ovmAddress`: The address of the deployed `ObolValidatorManager` contract.
- `newPrincipalRecipient`: The address of the new principal recipient.

```bash
forge script script/ovm/SetPrincipalRecipientScript.s.sol --sig "run(address,address)" \
   --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast 0x197d3c66a06FfD98F7316D71190EbD74262103b5 0xE84E904936C595C55b9Ad08532d9aD0A5d76df72
```

Typical output:

```
== Logs ==
  Current principal recipient 0x46aB8712c7A5423b717F648529B1c7A17099750A
  New principal recipient set to 0xE84E904936C595C55b9Ad08532d9aD0A5d76df72
```

## SetAmountOfPrincipalStakeScript

This script calls `setAmountOfPrincipalStake()` for an `ObolValidatorManager` contract.

To run this script, the following environment variables must be set:
- `PRIVATE_KEY`: the private key of the account that will call the function

Script parameters:
- `ovmAddress`: The address of the deployed `ObolValidatorManager` contract.
- `newAmount`: New amount of principal stake (wei).

```bash
forge script script/ovm/SetAmountOfPrincipalStakeScript.s.sol --sig "run(address,uint256)" \
   --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast \
   0x197d3c66a06FfD98F7316D71190EbD74262103b5 2000000000000000000
```

Typical output:

```
== Logs ==
  Current amount of principal stake 1000000000000000000
  New amount of principal stake 2000000000000000000
```

## SetRewardRecipientScript

This script calls `setRewardRecipient()` for an ObolValidatorManager contract.

To run this script, the following environment variables must be set:
- `PRIVATE_KEY`: the private key of the account that will call the function

Script parameters:
- `ovmAddress`: The address of the deployed `ObolValidatorManager` contract.
- `newRewardRecipient`: The address of the new reward recipient.

```bash
forge script script/ovm/SetRewardRecipientScript.s.sol --sig "run(address,address)" \
   --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast 0x197d3c66a06FfD98F7316D71190EbD74262103b5 0xE84E904936C595C55b9Ad08532d9aD0A5d76df72
```

Typical output:

```
== Logs ==
  Current reward recipient 0x46aB8712c7A5423b717F648529B1c7A17099750A
  New reward recipient set to 0xE84E904936C595C55b9Ad08532d9aD0A5d76df72
```

## RequestConsolidationScript

This script calls `requestConsolidation()` for an `ObolValidatorManager` contract.
*By default, the script uses at most 100 wei for the fee, but the change is returned.*

To run this script, the following environment variables must be set:
- `PRIVATE_KEY`: the private key of the account that will call the function

Script parameters:
- `ovmAddress`: The address of the deployed `ObolValidatorManager` contract.
- `src`: The source validator public key (hex).
- `dst`: The destination validator public key (hex).

```bash
forge script script/ovm/RequestConsolidationScript.s.sol --sig "run(address,bytes,bytes)" \
   --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast \
   0x197d3c66a06FfD98F7316D71190EbD74262103b5 \
   0x99bcf2494c940e21301b56c2358a3733b5b1035aa2d0856274b1015fe52d9116d74a771190e954190fcf8b607107de03 \
   0xa035b995117ddd4d34d5b9cae477795183b6805563c301c3e8a323d68aeef614ee9b6509cc0781c53f5ab545f78be46c
```

## RequestWithdrawalScript

This script calls `requestWithdrawal()` for an `ObolValidatorManager` contract.
*By default, the script uses at most 100 wei for the fee, but the change is returned.*

To run this script, the following environment variables must be set:
- `PRIVATE_KEY`: the private key of the account that will call the function

Script parameters:
- `ovmAddress`: The address of the deployed `ObolValidatorManager` contract.
- `src`: The validator public key (hex).
- `amount`: The amount to withdraw (gwei).

```bash
forge script script/ovm/RequestWithdrawalScript.s.sol --sig "run(address,bytes,uint64)" \
   --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast \
   0x197d3c66a06FfD98F7316D71190EbD74262103b5 \
   0x99bcf2494c940e21301b56c2358a3733b5b1035aa2d0856274b1015fe52d9116d74a771190e954190fcf8b607107de03 \
   10000000000
```

## DepositScript

This script calls the `deposit()` function on an `ObolValidatorManager` contract.
Your account must have enough ETH to cover the deposit amounts; otherwise, the script will stop.
The depositing account must be the owner or an address with the `DEPOSIT_ROLE`.

To run this script, the following environment variables must be set:
- `PRIVATE_KEY`: the private key of the account that will call the function

Script parameters:
- `ovmAddress`: The address of the deployed `ObolValidatorManager` contract.
- `depositFilePath`: The file path to the deposit data JSON file.

Usage:

```bash
forge script script/ovm/DepositScript.s.sol --sig "run(address,string)" \
   --rpc-url https://ethereum-sepolia-rpc.publicnode.com \
   --broadcast 0x197d3c66a06FfD98F7316D71190EbD74262103b5 my_deposit_data.json
```
