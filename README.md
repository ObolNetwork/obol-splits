![Obol Logo](https://obol.tech/obolnetwork.png)

<h1 align="center">Obol Manager Contracts</h1>

This repo intends to serve as a reference implementation of an Obol Manager smart contract. This suite of smart contracts and associated tests are intended to serve as a public good to to enable the safe and secure creation of Distributed Validators for Ethereum Consensus-based networks.

### Disclaimer

The following smart contracts are, as of now, un-audited, please do not use in production.

## Quickstart

This repo is built with [foundry](https://github.com/gakonst/foundry), a rust-based solidity development environment, and relies on [solmate](https://github.com/Rari-Capital/solmate), an efficient solidity smart contract library. Read the docs on our [docs site](https://docs.obol.tech/docs/sc/introducing-obol-managers) for more information on what Distributed Validators are, and their smart contract lifecycle.

### Installation

Follow the instructions here to install [foundry](https://github.com/gakonst/foundry#installation).

Then install the contract dependencies:

```sh
forge install
```

### Obol protocol contracts

- factory/ValidatorRewardSplitFactory.sol


- splitter/SplitFactory

- splitter/SplitMainV2.sol

- splitter/SplitWallet.sol

- waterfall/token/LW1155.sol

- waterfall/LWFactory.sol


### Local Development

To test your changes to the codebase run the unit tests with:

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

#### Goerli

OptimisticWithdrawalRecipientFactory: https://goerli.etherscan.io/address/0xe9557FCC055c89515AE9F3A4B1238575Fcd80c26#readContract

OptimisticWithdrawalRecipient: https://goerli.etherscan.io/address/0x898516b26D99d0F389598acFcd9F115Ab8184Fe3

ImmutableSplitControllerFactory: https://goerli.etherscan.io/address/0x64a2c4A50B1f46c3e2bF753CFe270ceB18b5e18f

ImmutableSplitController: https://goerli.etherscan.io/address/0x009894cdA6cB6d99866ca8E04e8EDeabd625712F

ObolLidoSplitFactory: https://goerli.etherscan.io/address/0x40435F54cc57943C727d8f856A52d4E55501cA8C

ObolLidoSplit: https://goerli.etherscan.io/address/0xdF46B2f36ffb67492A73263Ae3C3849B99DA9967


#### Sepolia

OptimisticWithdrawalRecipientFactory: https://sepolia.etherscan.io/address/0xca78f8fda7ec13ae246e4d4cd38b9ce25a12e64a

OptimisticWithdrawalRecipient: https://sepolia.etherscan.io/address/0x99585e71ab1118682d51efefca0a170c70eef0d6


#### Mainnet

OptimisticWithdrawalRecipientFactory: https://etherscan.io/address/0x119acd7844cbdd5fc09b1c6a4408f490c8f7f522

OptimisticWithdrawalRecipient: https://etherscan.io/address/0xe11eabf19a49c389d3e8735c35f8f34f28bdcb22


### Versioning

Versioning of releases to this repo has not been implemented.
