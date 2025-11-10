# ObolValidatorManager scripts

## RPC Endpoints

You can use any RPC endpoint, but here are some public ones suitable for running these scripts:

- Mainnet: https://ethereum-rpc.publicnode.com
- Sepolia: https://ethereum-sepolia-rpc.publicnode.com
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
- `beneficiary`: The address of the beneficiary recipient.
- `rewardRecipient`: The address of the reward recipient.
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
# ```bash
#   SET_BENEFICIARY_ROLE = 0x04 | RECOVER_FUNDS_ROLE = 0x0C
forge script script/ovm/GrantRoleScript.s.sol --sig "run(address,address,uint256)" \
   --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast \
   0x197d3c66a06FfD98F7316D71190EbD74262103b5 0xE84E904936C595C55b9Ad08532d9aD0A5d76df72 0x0C
```

Typical output:

```
== Logs ==
  Account 0xE84E904936C595C55b9Ad08532d9aD0A5d76df72 now has roles: 12
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

Typical output:

```
== Logs ==
  OVM address: 0x197d3c66a06FfD98F7316D71190EbD74262103b5
  --- State Before Distribution ---
  OVM balance: 32000000000 gwei
  Amount of principal stake: 32000000000 gwei
  Funds pending withdrawal: 0 gwei
  Principal threshold: 16000000000 gwei
  Beneficiary (principal recipient): 0x46aB8712c7A5423b717F648529B1c7A17099750A
  Reward recipient: 0xE84E904936C595C55b9Ad08532d9aD0A5d76df72
  --- Distributing Funds ---
  --- State After Distribution ---
  Amount of principal stake: 0 gwei
  Distribution completed successfully
```

After executing the script, verify your principal and reward recipient balances.

## SetBeneficiaryScript

This script calls `setBeneficiary()` for an ObolValidatorManager contract.

To run this script, the following environment variables must be set:
- `PRIVATE_KEY`: the private key of the account that will call the function

Script parameters:
- `ovmAddress`: The address of the deployed `ObolValidatorManager` contract.
- `newBeneficiary`: The address of the new beneficiary recipient.

```bash
forge script script/ovm/SetBeneficiaryScript.s.sol --sig "run(address,address)" \
   --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast 0x197d3c66a06FfD98F7316D71190EbD74262103b5 0xE84E904936C595C55b9Ad08532d9aD0A5d76df72
```

Typical output:

```
== Logs ==
  OVM address: 0x197d3c66a06FfD98F7316D71190EbD74262103b5
  Current beneficiary: 0x46aB8712c7A5423b717F648529B1c7A17099750A
  New beneficiary: 0xE84E904936C595C55b9Ad08532d9aD0A5d76df72
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
  OVM address: 0x197d3c66a06FfD98F7316D71190EbD74262103b5
  Current amount of principal stake: 1000000000 gwei
  New amount of principal stake: 2000000000 gwei
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
  OVM address: 0x197d3c66a06FfD98F7316D71190EbD74262103b5
  Current reward recipient: 0x46aB8712c7A5423b717F648529B1c7A17099750A
  New reward recipient: 0xE84E904936C595C55b9Ad08532d9aD0A5d76df72
```

## ConsolidateScript

This script calls `consolidate()` for an `ObolValidatorManager` contract.

The `consolidate()` function signature uses a `ConsolidationRequest[]` structure and includes:
- `maxFeePerConsolidation`: Maximum fee willing to pay per consolidation operation
- `excessFeeRecipient`: Address to receive any excess ETH beyond actual fees
- Support for batching multiple consolidation operations in a single transaction
- Enhanced validation (max 63 source validators per consolidation, EIP-7251 compliance)

To run this script, the following environment variables must be set:
- `PRIVATE_KEY`: the private key of the account that will call the function

Script parameters:
- `ovmAddress`: The address of the deployed `ObolValidatorManager` contract.
- `src`: The source validator public key (hex, 48 bytes).
- `dst`: The destination validator public key (hex, 48 bytes).
- `maxFeePerConsolidation`: Maximum fee per consolidation operation (wei).
- `excessFeeRecipient`: Address to receive excess fees.

```bash
forge script script/ovm/ConsolidateScript.s.sol --sig "run(address,bytes,bytes,uint256,address)" \
   --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast \
   0x197d3c66a06FfD98F7316D71190EbD74262103b5 \
   0x99bcf2494c940e21301b56c2358a3733b5b1035aa2d0856274b1015fe52d9116d74a771190e954190fcf8b607107de03 \
   0xa035b995117ddd4d34d5b9cae477795183b6805563c301c3e8a323d68aeef614ee9b6509cc0781c53f5ab545f78be46c \
   1000000000000000 \
   0x46aB8712c7A5423b717F648529B1c7A17099750A
```

Typical output:

```
== Logs ==
  OVM address: 0x197d3c66a06FfD98F7316D71190EbD74262103b5
  Source pubkey (first 20 bytes):
  0x99bcf2494c940e21301b56c2358a3733b5b1035a
  Destination pubkey (first 20 bytes):
  0xa035b995117ddd4d34d5b9cae477795183b68055
  Max fee per consolidation: 1000000000000000 wei
  Excess fee recipient: 0x46aB8712c7A5423b717F648529B1c7A17099750A
  Consolidation request submitted successfully
```

**Note**: The script internally converts the single source/destination pair into a `ConsolidationRequest[]` structure as required by the function signature.

## WithdrawScript

This script calls `withdraw()` for an `ObolValidatorManager` contract.

The `withdraw()` function signature includes:
- `maxFeePerWithdrawal`: Maximum fee willing to pay per withdrawal request
- `excessFeeRecipient`: Address to receive any excess ETH beyond actual fees  
- Support for batching multiple withdrawal requests in a single transaction
- Enhanced validation and reentrancy protection
- Automatic excess fee refunding with fallback event emission

To run this script, the following environment variables must be set:
- `PRIVATE_KEY`: the private key of the account that will call the function

Script parameters:
- `ovmAddress`: The address of the deployed `ObolValidatorManager` contract.
- `pubkey`: The validator public key (hex, 48 bytes).
- `amount`: The amount to withdraw (gwei).
- `maxFeePerWithdrawal`: Maximum fee per withdrawal request (wei).
- `excessFeeRecipient`: Address to receive excess fees.

```bash
forge script script/ovm/WithdrawScript.s.sol --sig "run(address,bytes,uint64,uint256,address)" \
   --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast \
   0x197d3c66a06FfD98F7316D71190EbD74262103b5 \
   0x99bcf2494c940e21301b56c2358a3733b5b1035aa2d0856274b1015fe52d9116d74a771190e954190fcf8b607107de03 \
   10000000000 \
   1000000000000000 \
   0x46aB8712c7A5423b717F648529B1c7A17099750A
```

Typical output:

```
== Logs ==
  OVM address: 0x197d3c66a06FfD98F7316D71190EbD74262103b5
  Withdrawing for pubkey (first 20 bytes):
  0x99bcf2494c940e21301b56c2358a3733b5b1035a
  Amount to withdraw: 10000000000 gwei
  Max fee per withdrawal: 1000000000000000 wei
  Excess fee recipient: 0x46aB8712c7A5423b717F648529B1c7A17099750A
  --- Executing Withdraw ---
  Withdrawal request submitted successfully
```

**Note**: The script internally converts the single validator/amount pair into arrays as required by the batch-supporting function signature.

## SweepScript

This script calls `sweep()` for an `ObolValidatorManager` contract to sweep funds from the pull balance to a recipient.

The `sweep()` function behavior:
- If `beneficiary` is `address(0)`, funds are swept to the principal recipient (anyone can call)
- If `beneficiary` is specified, only the owner can call and funds are swept to that address
- If `amount` is `0`, all available pull balance for the principal recipient is swept
- Otherwise, the specified amount is swept

To run this script, the following environment variables must be set:
- `PRIVATE_KEY`: the private key of the account that will call the function

Script parameters:
- `ovmAddress`: The address of the deployed `ObolValidatorManager` contract.
- `beneficiary`: The beneficiary address (`address(0)` to sweep to principal recipient).
- `amount`: Amount to sweep in wei (`0` to sweep all available balance).

```bash
# Sweep all funds to principal recipient (anyone can call)
forge script script/ovm/SweepScript.s.sol --sig "run(address,address,uint256)" \
   --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast \
   0x197d3c66a06FfD98F7316D71190EbD74262103b5 \
   0x0000000000000000000000000000000000000000 \
   0

# Sweep specific amount to custom beneficiary (owner only)
forge script script/ovm/SweepScript.s.sol --sig "run(address,address,uint256)" \
   --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast \
   0x197d3c66a06FfD98F7316D71190EbD74262103b5 \
   0xE84E904936C595C55b9Ad08532d9aD0A5d76df72 \
   1000000000000000000
```

Typical output:

```
== Logs ==
  OVM address: 0x197d3c66a06FfD98F7316D71190EbD74262103b5
  --- State Before Sweep ---
  Principal recipient: 0x46aB8712c7A5423b717F648529B1c7A17099750A
  Pull balance for principal recipient: 16000000000 gwei
  Funds pending withdrawal: 16000000000 gwei
  Sweeping to principal recipient (no beneficiary override)
  Amount: ALL available pull balance
  --- Executing Sweep ---
  --- State After Sweep ---
  Pull balance for principal recipient: 0 gwei
  Funds pending withdrawal: 0 gwei
  Sweep completed successfully
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

Typical output:

```
== Logs ==
  Reading deposit data from file: my_deposit_data.json
  Number of deposit records: 1
  Deposit at index 0 for amount of 32000000000 gwei:
    PK: 0x99bcf2494c940e21301b56c2358a3733b5b1035aa2d0856274b1015fe52d9116d74a771190e954190fcf8b607107de03
    WC: 0x010000000000000000000000197d3c66a06ffd98f7316d71190ebd74262103b5
  Total amount will be deposited: 32000000000 gwei
  Currently staked amount: 0 gwei
  --- Executing Deposits ---
  Depositing 0x99bcf2494c940e21301b56c2358a3733b5b1035aa2d0856274b1015fe52d9116d74a771190e954190fcf8b607107de03 for amount of 32000000000 gwei
  Deposit successful for amount: 32000000000 gwei
  All deposits executed successfully.
```
