# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

```sh
# Setup
forge install && cp .env.sample .env  # fill in RPC URLs and ETHERSCAN_API_KEY

# Build
forge build

# Test
forge test -vvv                                          # all tests
forge test --match-contract ObolLidoSplitTest -vvv       # specific contract
forge test --match-contract ObolLidoSplitTest --match-test testCanDistribute -vv  # specific test
forge test --gas-report                                  # with gas reporting

# Format
forge fmt
```

Integration tests require `MAINNET_RPC_URL` and/or `SEPOLIA_RPC_URL` in `.env` for forked tests.

## Architecture

Solidity 0.8.19 on Foundry, targeting Shanghai EVM. The codebase provides composable contracts for Distributed Validator fund distribution, integrating with 0xSplits, Lido, Ether.fi, and Ethereum consensus layer contracts.

### Core Pattern: Factory + Clone

Nearly every contract has a corresponding factory that deploys minimal proxies using solady's `LibClone` (CWIA — Constructor With Immutable Arguments stored in code, not storage). **Exception**: `ObolValidatorManagerFactory` deploys full instances via `new`.

### Contract Modules

| Module | Key Contract | Purpose |
|--------|-------------|---------|
| `src/base/` | `BaseSplit`, `BaseSplitFactory` | Abstract base for all splitting contracts. Fee mechanism: `PERCENTAGE_SCALE = 1e5` |
| `src/collector/` | `ObolCollector` | Generic ETH/ERC20 reward collector with fee + distribute |
| `src/lido/` | `ObolLidoSplit` | Wraps rebasing stETH→wstETH before distributing to SplitWallet |
| `src/etherfi/` | `ObolEtherfiSplit` | Same pattern: wraps rebasing eETH→weETH |
| `src/owr/` | `OptimisticWithdrawalRecipient` | ETH-only withdrawal with principal/reward threshold (16 ether). `src/owr/token/` adds ERC20 support |
| `src/ovm/` | `ObolValidatorManager` | Validator lifecycle management: deposit, consolidation (EIP-7251), withdrawal (EIP-7002), distribution. Role-based access via solady `OwnableRoles` |
| `src/controllers/` | `ImmutableSplitController` | Manages 0xSplits config updates with hardcoded recipients |

### Key Design Decisions

- **ETH as `address(0)`**: Throughout the codebase, native ETH is represented as `address(0)` in token parameters.
- **PUSH/PULL distribution**: `PUSH (0)` transfers directly; `PULL (1)` defers via `withdrawPullBalance()`. Pull mode prevents malicious recipient DOS.
- **Binary recipients**: OWR and OVM support exactly 2 recipients (principal and reward), routed by balance threshold.
- **Rebasing wrapping**: Lido and Ether.fi integrations wrap rebasing tokens before sending to 0xSplits, which can't handle rebasing tokens natively.
- **SafeTransferLib**: All token transfers use solmate's `SafeTransferLib`.

### Test Organization

Tests in `src/test/` mirror the source structure. Each module has:
- Unit tests (`.t.sol` suffix)
- Test helpers (e.g., `ObolLidoSplitTestHelper.sol`)
- `integration/` subdirectories for fork-based tests
- Mocks in `src/test/utils/mocks/` and `src/test/ovm/mocks/`

Fuzz testing configured at 100 runs.

### Formatting

Configured in `foundry.toml [fmt]`: 2-space indentation, 120 char line length, no bracket spacing, double quotes, `attributes_first` multiline func headers.

### Deployment Scripts

Scripts in `script/`, with OVM-specific scripts in `script/ovm/`. Lido deployment uses JSON config files from `script/data/`.
