![Obol Logo](https://obol.tech/obolnetwork.png)

<h1 align="center">Obol Splits</h1>

This repo contains Obol Splits smart contracts. This suite of smart contracts and associated tests are intended to serve as a public good to enable the safe and secure creation of Distributed Validators for Ethereum Consensus-based networks.

### Disclaimer

The following smart contracts are provided as is, without warranty. Details of their audit can be consulted [here](https://docs.obol.tech/docs/sec/smart_contract_audit). 

## Quickstart

This repo is built with [foundry](https://github.com/foundry-rs/foundry), a rust-based solidity development environment, and relies on [solmate](https://github.com/Rari-Capital/solmate), an efficient solidity smart contract library. Read the docs on our [docs site](https://docs.obol.tech/docs/next/sc/introducing-obol-splits) for more information on what Distributed Validators are, and their smart contract lifecycle.

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

### Goerli Network Contracts
| Contract Type                        | Address                                                                                             |
|--------------------------------------|-----------------------------------------------------------------------------------------------------|
| OptimisticWithdrawalRecipientFactory | [0xe9557FCC055c89515AE9F3A4B1238575Fcd80c26](https://goerli.etherscan.io/address/0xe9557FCC055c89515AE9F3A4B1238575Fcd80c26) |
| OptimisticWithdrawalRecipient        | [0x898516b26D99d0F389598acFcd9F115Ab8184Fe3](https://goerli.etherscan.io/address/0x898516b26D99d0F389598acFcd9F115Ab8184Fe3) |
| ImmutableSplitControllerFactory     | [0x64a2c4A50B1f46c3e2bF753CFe270ceB18b5e18f](https://goerli.etherscan.io/address/0x64a2c4A50B1f46c3e2bF753CFe270ceB18b5e18f) |
| ImmutableSplitController            | [0x009894cdA6cB6d99866ca8E04e8EDeabd625712F](https://goerli.etherscan.io/address/0x009894cdA6cB6d99866ca8E04e8EDeabd625712F) |
| ObolLidoSplitFactory                | [0x40435F54cc57943C727d8f856A52d4E55501cA8C](https://goerli.etherscan.io/address/0x40435F54cc57943C727d8f856A52d4E55501cA8C) |
| ObolLidoSplit                       | [0xdF46B2f36ffb67492A73263Ae3C3849B99DA9967](https://goerli.etherscan.io/address/0xdF46B2f36ffb67492A73263Ae3C3849B99DA9967) |

### Sepolia Network Contracts
| Contract Type                        | Address                                                                                             |
|--------------------------------------|-----------------------------------------------------------------------------------------------------|
| OptimisticWithdrawalRecipientFactory | [0xca78f8fda7ec13ae246e4d4cd38b9ce25a12e64a](https://sepolia.etherscan.io/address/0xca78f8fda7ec13ae246e4d4cd38b9ce25a12e64a) |
| OptimisticWithdrawalRecipient        | [0x99585e71ab1118682d51efefca0a170c70eef0d6](https://sepolia.etherscan.io/address/0x99585e71ab1118682d51efefca0a170c70eef0d6) |

### Holesky Network Contracts
| Contract Type        | Address                                                                                         |
|----------------------|-------------------------------------------------------------------------------------------------|
| ObolLidoSplitFactory | [0x934ec6B68cE7cC3b3E6106C686B5ad808ED26449](https://holesky.etherscan.io/address/0x934ec6B68cE7cC3b3E6106C686B5ad808ED26449) |
| ObolLidoSplit       | [0x22bdC6609de39E569546184Bff4ba4716d34fEBd](https://holesky.etherscan.io/address/0x22bdC6609de39E569546184Bff4ba4716d34fEBd) |
| OptimisticWithdrawalRecipientFactory | [0xc0961353fcc43a99e3041db07ac646720e116256](https://holesky.etherscan.io/address/0xc0961353fcc43a99e3041db07ac646720e116256) |
| OptimisticWithdrawalRecipient        | [0xa70eb35c1ee7f96688ea5e530ddf1ebedd0c8259](https://holesky.etherscan.io/address/0xa70eb35c1ee7f96688ea5e530ddf1ebedd0c8259) |
| OptimisticTokenWithdrawalRecipientFactory | [0xD6c9f28062834185FF65D61388D9E2d9D804Fc03](https://holesky.etherscan.io/address/0xD6c9f28062834185FF65D61388D9E2d9D804Fc03) |
| OptimisticTokenWithdrawalRecipient        | [0xb927bf07d1686A7Ad06Fae18e632232a8498F0f6](https://holesky.etherscan.io/address/0xb927bf07d1686A7Ad06Fae18e632232a8498F0f6) |


### Mainnet Contracts
| Contract Type                        | Address                                                                                             |
|--------------------------------------|-----------------------------------------------------------------------------------------------------|
| OptimisticWithdrawalRecipientFactory | [0x119acd7844cbdd5fc09b1c6a4408f490c8f7f522](https://etherscan.io/address/0x119acd7844cbdd5fc09b1c6a4408f490c8f7f522) |
| OptimisticWithdrawalRecipient        | [0xe11eabf19a49c389d3e8735c35f8f34f28bdcb22](https://etherscan.io/address/0xe11eabf19a49c389d3e8735c35f8f34f28bdcb22) |
| ObolLidoSplitFactory                | [0xA9d94139A310150Ca1163b5E23f3E1dbb7D9E2A6](https://etherscan.io/address/0xA9d94139A310150Ca1163b5E23f3E1dbb7D9E2A6) |
| ObolLidoSplit                       | [0x2fB59065F049e0D0E3180C6312FA0FeB5Bbf0FE3](https://etherscan.io/address/0x2fB59065F049e0D0E3180C6312FA0FeB5Bbf0FE3) |
| ImmutableSplitControllerFactory     | [0x49e7cA187F1E94d9A0d1DFBd6CCCd69Ca17F56a4](https://etherscan.io/address/0x49e7cA187F1E94d9A0d1DFBd6CCCd69Ca17F56a4) |
| ImmutableSplitController            | [0xaF129979b773374dD3025d3F97353e73B0A6Cc8d](https://etherscan.io/address/0xaF129979b773374dD3025d3F97353e73B0A6Cc8d) |

### Gnosis Chain Mainnet Contracts
| Contract Type                        | Address                                                                                             |
|--------------------------------------|-----------------------------------------------------------------------------------------------------|
| OptimisticTokenWithdrawalRecipientFactory | [0x417C41a1A49316dFdC317C1459d04C9959a67972](https://gnosisscan.io/address/0x417C41a1A49316dFdC317C1459d04C9959a67972) |
| OptimisticTokenWithdrawalRecipient        | [0xdd94984658d4B9C45dDF1652287c15A672021894](https://gnosisscan.io/address/0xdd94984658d4B9C45dDF1652287c15A672021894) |

### Gnosis Chain Chiado Contracts
| Contract Type                        | Address                                                                                             |
|--------------------------------------|-----------------------------------------------------------------------------------------------------|
| OptimisticTokenWithdrawalRecipientFactory | [0x417C41a1A49316dFdC317C1459d04C9959a67972](https://gnosis-chiado.blockscout.com/address/0x417C41a1A49316dFdC317C1459d04C9959a67972) |
| OptimisticTokenWithdrawalRecipient        | [0xdd94984658d4b9c45ddf1652287c15a672021894](https://gnosis-chiado.blockscout.com/address/0xdd94984658d4b9c45ddf1652287c15a672021894) |


### Versioning

Versioning of releases to this repo has not been implemented.
