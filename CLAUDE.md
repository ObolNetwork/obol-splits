# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Obol Splits is a suite of Solidity smart contracts enabling safe creation and management of Distributed Validators for Ethereum Consensus-based networks. Built with Foundry, targeting Solidity 0.8.19 with Shanghai EVM compatibility.

## Development Commands

### Setup
```sh
# Install Foundry first: https://github.com/foundry-rs/foundry#installation
forge install
cp .env.sample .env
```

### Testing
```sh
# Run all tests
forge test

# Run specific test
forge test --match-contract ContractTest --match-test testFunction -vv

# Run with gas reporting
forge test --gas-report
```

### Building
```sh
# Compile contracts and generate ABIs
forge build
```

### Deployment
```sh
# Deploy using forge create or run deployment scripts in script/ directory
forge script script/DeployFactoryScript.s.sol
```

## Architecture Overview

### Core Contract Types

**ObolValidatorManager (OVM)** - Main validator management contract
- Manages ETH2 validator deposits, withdrawals (EIP-7002), and consolidations (EIP-7251)
- Uses role-based access control via OwnableRoles (6 distinct roles: WITHDRAWAL, CONSOLIDATION, SET_BENEFICIARY, RECOVER_FUNDS, SET_REWARD, DEPOSIT)
- Two-phase fund distribution: PUSH (direct transfer) or PULL (recipient withdraws later)
- Principal threshold in gwei determines recipient routing (>= threshold → principal, < threshold → reward)
- Location: src/ovm/ObolValidatorManager.sol

**OptimisticWithdrawalRecipient (OWR)** - ETH distribution contract
- Distributes ETH to two recipients based on 16 ETH threshold
- Uses Clone proxy pattern (Solady) for gas-efficient deployment
- Supports both PUSH and PULL distribution modes
- Location: src/owr/OptimisticWithdrawalRecipient.sol

**OptimisticTokenWithdrawalRecipient** - Multi-token version of OWR
- Same as OWR but accepts configurable threshold and any ERC20 token
- Location: src/owr/token/OptimisticTokenWithdrawalRecipient.sol

**ObolLidoSplit** - Lido integration wrapper
- Wraps rebasing stETH to non-rebasing wstETH for 0xSplits compatibility
- Uses BaseSplit pattern with Clone proxy
- Location: src/lido/ObolLidoSplit.sol

**ObolEtherfiSplit** - EtherFi integration wrapper
- Wraps rebasing eETH to non-rebasing weETH
- Identical pattern to ObolLidoSplit
- Location: src/etherfi/ObolEtherfiSplit.sol

**ImmutableSplitController** - 0xSplits controller
- Immutable configuration for 0xSplits SplitMain
- Uses CWIA (Contract With Immutable Arguments) pattern
- Location: src/controllers/ImmutableSplitController.sol

### Factory Pattern

All contracts use Clone factories for gas-efficient deployment via Solady's LibClone:
- OptimisticWithdrawalRecipientFactory
- OptimisticTokenWithdrawalRecipientFactory
- ObolValidatorManagerFactory
- ObolLidoSplitFactory
- ObolEtherfiSplitFactory
- ObolCollectorFactory
- ImmutableSplitControllerFactory

### Key Architectural Patterns

**Clone Proxy (Solady)**: Minimal proxy with constructor arguments encoded in bytecode (CWIA optimization). Used by OWR, ObolLidoSplit, ObolEtherfiSplit, ObolCollector, ImmutableSplitController.

**Two-Phase Distribution**: PUSH (0) for direct transfers, PULL (1) for deferred withdrawals. Prevents malicious recipients from blocking distributions.

**BaseSplit Template**: Abstract base class providing distribute(), rescueFunds(), and fee mechanism (PERCENTAGE_SCALE = 1e5). All split contracts inherit from this.

**Role-Based Access Control**: OVM uses bit-flag roles allowing multiple roles per address. Other contracts use standard Ownable or public functions.

**Rebasing Token Wrapping**: Intercepts rebasing tokens (stETH, eETH) and wraps to non-rebasing versions (wstETH, weETH) for 0xSplits integration.

## Important Constants and Values

- `BALANCE_CLASSIFICATION_THRESHOLD = 16 ether` (OWR threshold)
- `PERCENTAGE_SCALE = 1e5` (100000 = 100%)
- `PUBLIC_KEY_LENGTH = 48` (validator pubkey length)
- OVM threshold stored in gwei, converted to wei via `threshold * 1e9`

## External Integrations

- **0xSplits**: SplitMain for fund distribution
- **Lido**: stETH/wstETH token wrapping
- **EtherFi**: eETH/weETH token wrapping
- **Ethereum Deposit Contract**: ETH2 staking deposits
- **EIP-7002 System Contract**: Partial withdrawal requests (address 0x09Fc772D0857550724b07B850a4323f39112aAaA)
- **EIP-7251 System Contract**: Validator consolidation requests (address 0x00431C4A4e22b7cbe7fc2f3DDa91BE1D4dF9EFf6)
- **ENS Reverse Registrar**: Contract naming

## Project Structure

```
src/
├── base/             BaseSplit and BaseSplitFactory abstracts
├── collector/        ObolCollector for reward collection
├── controllers/      ImmutableSplitController
├── etherfi/          EtherFi integration (eETH → weETH)
├── interfaces/       All interface definitions
├── lido/             Lido integration (stETH → wstETH)
├── ovm/              ObolValidatorManager (main validator manager)
├── owr/              OptimisticWithdrawalRecipient (ETH distribution)
│   └── token/        Token-based withdrawal recipient
└── test/             Test suite organized by feature

script/               24+ deployment scripts
```

## Testing Approach

- **Unit tests**: Individual contract functionality, role checks, fee calculations
- **Integration tests**: End-to-end flows (lido/, etherfi/, owr/token/integration/)
- **Mocks**: SystemContractMock (EIP-7002/7251), DepositContractMock, MockERC20/1155/NFT
- **Fuzzing**: Configured for 100 runs per test
- Test files mirror src/ structure and use .t.sol suffix

## Security Features

- Reentrancy protection on OVM distribution functions
- Two-phase distribution prevents denial-of-service
- Role-based access control with granular permissions
- Fund recovery mechanisms for stuck tokens
- Public key validation (48-byte length checks)
- Immutable configurations via CWIA pattern

## Deployment Addresses

**Mainnet:**
- OptimisticWithdrawalRecipientFactory: 0x119acd7844cbdd5fc09b1c6a4408f490c8f7f522
- OptimisticWithdrawalRecipient: 0xe11eabf19a49c389d3e8735c35f8f34f28bdcb22
- ObolLidoSplitFactory: 0xA9d94139A310150Ca1163b5E23f3E1dbb7D9E2A6
- ObolLidoSplit: 0x2fB59065F049e0D0E3180C6312FA0FeB5Bbf0FE3
- ImmutableSplitControllerFactory: 0x49e7cA187F1E94d9A0d1DFBd6CCCd69Ca17F56a4
- ImmutableSplitController: 0xaF129979b773374dD3025d3F97353e73B0A6Cc8d

**Sepolia:**
- OptimisticWithdrawalRecipientFactory: 0xca78f8fda7ec13ae246e4d4cd38b9ce25a12e64a
- OptimisticWithdrawalRecipient: 0x99585e71ab1118682d51efefca0a170c70eef0d6

## Important Notes

- Project uses Foundry's Shanghai EVM version
- Solidity version: 0.8.19
- Gas reporting enabled for all contracts
- Audited contracts - see https://docs.obol.tech/docs/sec/smart_contract_audit
- Code formatting: 2-space tabs, 120 char line length, no bracket spacing
