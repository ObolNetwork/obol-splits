![Obol Logo](https://obol.tech/obolnetwork.png)

<h1 align="center">Obol Manager Contracts</h1>

This repo intends to serve as a reference implementation of an Obol Manager smart contract. This suite of smart contracts and associated tests are intended to serve as a public good to to enable the safe and secure creation of Distributed Validators for Ethereum Consensus-based networks.

### Disclaimer

The following smart contracts are, as of now, un-audited, please do not use in production.

## Quickstart

This repo is built with [foundry](https://github.com/gakonst/foundry), a rust-based solidity development environment.

### Installation

Follow the instructions here to install [foundry](https://github.com/gakonst/foundry#installation)

Then install the contract dependencies

```sh
forge install rari-capital/solmate 
forge install dapphub/ds-test
```

### Local Development

```sh
# To run the tests
forge test
```

This command starts runs all tests.

### Build

```sh
forge build
```

This command generates compilation output into the `out` directory.

### Deployment

This repo can be deployed with `forge create`. 

### Versioning

Versioning of releases to this repo has not been implemented.

