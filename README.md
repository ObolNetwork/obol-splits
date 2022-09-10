![Obol Logo](https://obol.tech/obolnetwork.png)

<h1 align="center">Obol Manager Contracts</h1>

This repo intends to serve as a reference implementations of Obol Manager smart contracts. This suite of smart contracts and associated tests are intended to serve as a public good to to enable the safe and secure creation of Distributed Validators for Ethereum Consensus-based networks.

## Disclaimer

**The following smart contracts are, as of now, un-audited, please do not use in production.**

## Quickstart

This repo is built with [foundry](https://github.com/gakonst/foundry), a rust-based solidity development environment, and relies on [0xSplits](https://github.com/0xSplits/splits-contracts), [solmate](https://github.com/Rari-Capital/solmate), and [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts) smart contract libraries. Read more on our [docs site](https://docs.obol.tech/docs/sc/introducing-obol-managers) about what Distributed Validators are, and their smart contract lifecycle.

### Installation

Follow the instructions here to install [foundry](https://github.com/gakonst/foundry#installation).

Then install the contract dependencies:

```sh
git submodule update
```

### Local Development

To test your changes to the codebase run the unit tests with:

```sh
forge test --via-ir
```

This command starts runs all tests.

> NOTE: To run a specific test:
```sh
forge test --via-ir --match-contract ContractTest --match-test testFunction -vv
```

### Build

To compile your smart contracts and generate their ABIs run:

```sh
forge build --via-ir
```

This command generates compilation output into the `out` directory.

### Deployment

This repo can be deployed with `forge create`. 

### Versioning

Versioning of releases to this repo has not been implemented.


# Contract Overview

## WithdrawalRecipientOwnable

This is the simplest withdrawal recipient contract, and has two methods, `withdraw()`, and `changeOwner()`, both of which can only be called by the current owner of the smart contract. This allows the change of beneficial ownership of a validator without its exit, and is a good building block on top of which to build more complex validator tokenisation contracts.

## WithdrawalRecipientRewardSplit

Implemented by [0xArbiter](https://github.com/The-Arbiter).

This smart contract is used to wrap an 0xSplits deterministic splitter contract. The purpose of this contract is to receive staking rewards, allowing the depositor to retrieve their 32 Ether staking principal directly whilst forwarding any excess amounts to an 0xSplits splitter. 

This smart contract, if set as an 0x01 withdrawal credential for an Ethereum validator, will allow 32 ether to flow to the deployer (contract owner), before switching to forwarding all ether to an 0xSplits splitter contract from there on. 

This is a common withdrawal pattern used in most delegated staking models where fees are calculated as a percentage of profits earned not principal. This implementation of reward splitting however does favour the depositor rather than the operator, as they get paid in full first before the operator gets paid, this is a result of the lack of visibility from the EVM side to the consensus layer withdrawals process. Until a future where the EVM can read consensus layer [state](https://eips.ethereum.org/EIPS/eip-4788), solidity contracts can't easily differentiate between a reward skim, a block proposal/mev-bribe, a normal eth transaction, or a severe slashing. This means this contract assumes only one validator will point at it, and that until 32 ether has flown through it to the owner, it cannot be sure that the principal of the deposit has been repaid.  

### How does this Withdrawal Recipient Reward Split Contract work?

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

To deploy the reward split contract you must first create a split. The 0xSplits team [maintain a dapp](https://docs.0xsplits.xyz/smartcontracts/overview#addresses) for creating splits. 

You must also pass in the address of the 0xSplits `SplitMain.sol` contract on [the network you're deploying to](https://docs.0xsplits.xyz/smartcontracts/overview#addresses) in the constructor for `WithdrawalRecipientRewardSplit`. 

```solidity
// Constructor takes the deterministic splitter address and the 0xSplits SplitMain contract address
	
	constructor (address splitterAddress_, SplitMain _splitmain) {
	
	splitter = _splitmain;
	
	splitterAddress = splitterAddress_;
	
}
```
