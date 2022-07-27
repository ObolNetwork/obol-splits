# Obol Labs - 0xSplits Wrapper
*by 0xArbiter*

<img src="/img/banner.png"/>
**This smart contract is used to wrap a 0xSplits deterministic splitter. The purpose of this contract is to receive staking rewards, allowing the depositor to retrieve their 32 Ether staking principal directly whilst forwarding any excess amounts to a 0xSplits splitter.**

### How can I run this?

This is built in Forge/Foundry and has Solmate and OpenZeppelin dependencies (Solmate for 0xSplits code and OpenZeppelin for `Ownable`). The test contract is very heavy so you will have to use intermediate representation to get it to run.

First, install Forge/Foundry and install Solmate and OpenZeppelin by following [this guide](https://mirror.xyz/juliancanderson.eth/D94omhhrd4wiWkqSWjY55y-jhtVIBLl9ZZoHk1IERPE) to install the necessary dependencies. Once you're set up, run the following line:

`forge test --via-ir `

or if you want to see more verbose execution:

`forge test -vvvvv --via-ir `

### How does this work?

0xSplits has a main contract `SplitMain.sol` that deploys either deterministic or non-deterministic splitter contracts which are derived from parameters like list of accounts and split percentages.

There are three main functions within 0xSplits to know about:

1) `createSplit` exists on the main contract and allows for creation of a deterministic splitter by passing `address(0)` for the controller address.
2) `distributeETH` exists on the main contract and sends ETH from the deterministic splitter to the main contract as well as updating values inside of the main contract.
   <img src="/img/trace.png"/>
3) `withdraw` exists on the main contract and withdraws the funds (ETH and optionally tokens) for a given caller address.

This code uses `skimEther` to wrap the `distributeETH` function. It does not interact with the other two functions (however the testing contract does).

There are four functions:

- `withdrawEther` is *onlyOwner* (the staking depositor) and allows withdrawal of the contract balance to a specified address, up to a cumulative 32 Ether.
- `withdrawAllEther` wraps `withdrawEther` but uses the contract's balance as the amount to be withdrawn.
- `skimEther` will eventually become *onlyOperator* and allows forwarding of the contract's balance **beyond what is reserved for the depositor** (32 Ether) to the deterministic splitter. 
- `getBeneficiaryPrincipalOwed` returns the total remaining Ether reserved for the depositor.

### Gas Usage 

Here is a snapshot of gas usage:
<img src="/img/gasusage.png"/>

`withdrawEther` would be marginally less expensive than `withdrawAllEther` but was not included in this snapshot. 

You will notice that `skimEther` is expensive; this is because `distributeETH` is expensive.

### Security Considerations

`withdrawEther` is the only function which transfers Ether to an address specified by the caller. This function is *onlyOwner* and strictly follows the checks-effects-interaction pattern. It uses `transfer` to withdraw Ether.

`skimEther` is marked as external so **it is necessary to add an access modifier such as *onlyOperator* to this prior to production deployment**. This function transfers Ether to the deterministic splitter address which is stored in state in the constructor and cannot be altered beyond this. 

### Deploying this code

I've set it up such that you can simply pass in the address of the 0xSplits `SplitMain.sol` contract on the network you're deploying to in the constructor for `WithdrawalRecipientRewardSplit`:

```
// Constructor takes the deterministic splitter address and the 0xSplits SplitMain contract address
	
	constructor (address splitterAddress_, SplitMain _splitmain) {
	
	splitter = _splitmain;
	
	splitterAddress = splitterAddress_;
	
}
```

Here, `SplitMain` is just a contract type from `SplitMain.sol`.

You could also use Forge's `mainnet-forking` tool to deploy on mainnet.