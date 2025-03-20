![Obol Logo](https://obol.tech/obolnetwork.png)

<h1 align="center">Obol Splits</h1>

This repo contains Obol Splits smart contracts. This suite of smart contracts and associated tests are intended to serve as a public good to to enable the safe and secure creation of Distributed Validators for Ethereum Consensus-based networks.

### Disclaimer

The following smart contracts are provided as is, without warranty. Details of their audit can be consulted [here](https://docs.obol.tech/docs/sec/smart_contract_audit). 

## Quickstart

This repo is built with [foundry](https://github.com/foundry-rs/foundry), a rust-based solidity development environment, and relies on [solmate](https://github.com/Rari-Capital/solmate), an efficient solidity smart contract library. Read the docs on our [docs site](https://docs.obol.org/learn/intro/obol-splits) for more information on what Distributed Validators are, and their smart contract lifecycle.

### Installation

Follow the instructions here to install [foundry](https://github.com/foundry-rs/foundry#installation).

Then install the contract dependencies:

```sh
forge install
```

### Local Development

To test your changes to the codebase run the unit tests with:

```
cp .env.sample .env
```

```sh
forge test
```

This command starts runs all tests.

> NOTE: To run a specific test:
```sh
forge test --match-contract ContractTest --match-test testFunction -vv
```

### Build

To compile your smart contracts and generate their ABIs run:

```sh
forge build
```

This command generates compilation output into the `out` directory.

### Deployment

This repo can be deployed with `forge create` or running the deployment scripts.

#### Sepolia

OptimisticWithdrawalRecipientFactory: https://sepolia.etherscan.io/address/0xca78f8fda7ec13ae246e4d4cd38b9ce25a12e64a

OptimisticWithdrawalRecipient: https://sepolia.etherscan.io/address/0x99585e71ab1118682d51efefca0a170c70eef0d6


### Holesky

ObolLidoSplitFactory: https://holesky.etherscan.io/address/0x934ec6B68cE7cC3b3E6106C686B5ad808ED26449

ObolLidoSplit: https://holesky.etherscan.io/address/0x22bdC6609de39E569546184Bff4ba4716d34fEBd 


#### Mainnet

OptimisticWithdrawalRecipientFactory: https://etherscan.io/address/0x119acd7844cbdd5fc09b1c6a4408f490c8f7f522

OptimisticWithdrawalRecipient: https://etherscan.io/address/0xe11eabf19a49c389d3e8735c35f8f34f28bdcb22

ObolLidoSplitFactory: https://etherscan.io/address/0xA9d94139A310150Ca1163b5E23f3E1dbb7D9E2A6

ObolLidoSplit: https://etherscan.io/address/0x2fB59065F049e0D0E3180C6312FA0FeB5Bbf0FE3

ImmutableSplitControllerFactory: https://etherscan.io/address/0x49e7cA187F1E94d9A0d1DFBd6CCCd69Ca17F56a4

ImmutableSplitController: https://etherscan.io/address/0xaF129979b773374dD3025d3F97353e73B0A6Cc8d

### Versioning

Versioning of releases to this repo has not been implemented.
