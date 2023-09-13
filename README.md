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

OptimisticWithdrawalRecipient: https://goerli.etherscan.io/address/0xBB3b6CC2882B73eeFb32284Ecc9035839fb2C908

OptimisticWithdrawalRecipientFactory: https://goerli.etherscan.io/address/0x7b4b2cbbdac4f9b70252503a411574f4ff960e68 

ImmutableSplitControllerFactory: https://goerli.etherscan.io/address/0x64a2c4A50B1f46c3e2bF753CFe270ceB18b5e18f

ImmutableSplitController: https://goerli.etherscan.io/address/0x009894cdA6cB6d99866ca8E04e8EDeabd625712F

### Versioning

Versioning of releases to this repo has not been implemented.
