# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Obol Splits is a suite of Solidity smart contracts enabling safe creation and management of Distributed Validators for Ethereum Consensus-based networks. Built with Foundry, targeting Solidity 0.8.19 with Shanghai EVM compatibility.

## Development Commands

```sh
# Setup
forge install && cp .env.sample .env

# Testing
forge test                                    # All tests
forge test --match-contract C --match-test t  # Specific test
forge test --gas-report                       # With gas reporting

# Build & Deploy
forge build
forge script script/DeployFactoryScript.s.sol
```

## Architecture Overview

### Core Contract Types

**ObolValidatorManager (OVM)** - Validator management with ETH2 deposits, withdrawals (EIP-7002), consolidations (EIP-7251)
- 6 role-based permissions: WITHDRAWAL (0x01), CONSOLIDATION (0x02), SET_BENEFICIARY (0x04), RECOVER_FUNDS (0x08), SET_REWARD (0x10), DEPOSIT (0x20)
- PUSH/PULL distribution modes; principal threshold (gwei) routes funds
- `sweep()` extracts from `pullBalances[principalRecipient]` - anyone can call with beneficiary=address(0), owner for custom address
- Non-proxy (deployed via `new`, not Clone)

**OptimisticWithdrawalRecipient (OWR)** - ETH distribution via 16 ETH threshold, Clone proxy, PUSH/PULL modes

**OptimisticTokenWithdrawalRecipient** - OWR for ERC20 with configurable threshold

**ObolLidoSplit** - Wraps stETH→wstETH for 0xSplits (Clone + BaseSplit)

**ObolEtherfiSplit** - Wraps eETH→weETH for 0xSplits (Clone + BaseSplit)

**ImmutableSplitController** - Immutable 0xSplits config (CWIA pattern)

### Factory Pattern

Clone factories (Solady LibClone): OptimisticWithdrawalRecipientFactory, OptimisticTokenWithdrawalRecipientFactory, ObolLidoSplitFactory, ObolEtherfiSplitFactory, ObolCollectorFactory, ImmutableSplitControllerFactory

**Exception**: ObolValidatorManagerFactory deploys full instances via `new` (not clones)

### Key Patterns

- **Clone Proxy**: Minimal proxy with CWIA optimization (all except OVM)
- **Two-Phase Distribution**: PUSH (0) = direct transfer; PULL (1) = deferred via `withdrawPullBalance()`. Prevents malicious recipient DOS.
- **Sweep (OVM)**: Extract from `pullBalances[principalRecipient]`. Anyone if beneficiary=0, owner for custom address. Amount=0 sweeps all.
- **BaseSplit**: Abstract base with distribute(), rescueFunds(), fee mechanism (PERCENTAGE_SCALE=1e5)
- **Rebasing Wrapping**: stETH→wstETH, eETH→weETH for 0xSplits

## Constants & External Integrations

**Constants:**
- `BALANCE_CLASSIFICATION_THRESHOLD_GWEI = 16 ether / 1 gwei` (OVM tests), `BALANCE_CLASSIFICATION_THRESHOLD = 16 ether` (OWR)
- `PERCENTAGE_SCALE = 1e5`, `PUBLIC_KEY_LENGTH = 48`, Distribution modes: `PUSH = 0, PULL = 1`
- OVM Roles: WITHDRAWAL (0x01), CONSOLIDATION (0x02), SET_BENEFICIARY (0x04), RECOVER_FUNDS (0x08), SET_REWARD (0x10), DEPOSIT (0x20)

**Integrations:** 0xSplits (SplitMain), Lido (stETH/wstETH), EtherFi (eETH/weETH), Deposit Contract (ETH2), EIP-7002 (0x09Fc...aAaA), EIP-7251 (0x0043...EFf6), ENS Reverse Registrar

## Project Structure

```
src/
├── base/             BaseSplit and BaseSplitFactory abstracts
├── collector/        ObolCollector for reward collection
├── controllers/      ImmutableSplitController
├── etherfi/          EtherFi integration (eETH → weETH)
├── interfaces/       All interface definitions (IObolValidatorManager, etc.)
├── lido/             Lido integration (stETH → wstETH)
├── ovm/              ObolValidatorManager and ObolValidatorManagerFactory
├── owr/              OptimisticWithdrawalRecipient (ETH distribution)
│   └── token/        Token-based withdrawal recipient
└── test/             Test suite organized by feature
    ├── ovm/          OVM tests and mocks
    ├── owr/          OWR tests
    └── ...

script/               Deployment and management scripts
├── ovm/              OVM-specific scripts (12 scripts)
│   ├── DeployFactoryScript.s.sol
│   ├── CreateOVMScript.s.sol
│   ├── DepositScript.s.sol
│   ├── DistributeFundsScript.s.sol
│   ├── ConsolidateScript.s.sol
│   ├── WithdrawScript.s.sol
│   ├── GrantRolesScript.s.sol
│   ├── SetBeneficiaryScript.s.sol
│   ├── SetRewardRecipientScript.s.sol
│   ├── SetAmountOfPrincipalStakeScript.s.sol
│   ├── SystemContractFeesScript.s.sol
│   └── Utils.s.sol
├── splits/           0xSplits deployment scripts
└── data/             Sample configuration JSON files
```

## Testing & Security

**Testing:**
- Unit tests (role checks, fees, distribution), integration tests (lido/, etherfi/, owr/token/integration/)
- Mocks: SystemContractMock (EIP-7002/7251), DepositContractMock, MockERC20/1155/NFT
- 100 fuzz runs, .t.sol suffix, 43+ OVM tests (PUSH/PULL, sweep, roles, edge cases)
- OVM test pattern: ≥16 ether → beneficiary, <16 ether → reward

**Security:**
- ReentrancyGuard on OVM distribute/sweep
- PUSH/PULL prevents DOS, role-based access (6 OVM roles)
- Fund recovery via `recoverFunds()`, 48-byte pubkey validation
- Sweep allows emergency extraction, fee validation with refunds
- `fundsPendingWithdrawal` prevents over-distribution

## Deployment Addresses

**Mainnet:** OWRFactory: 0x119acd7844cbdd5fc09b1c6a4408f490c8f7f522, OWR: 0xe11eabf19a49c389d3e8735c35f8f34f28bdcb22, ObolLidoSplitFactory: 0xA9d94139A310150Ca1163b5E23f3E1dbb7D9E2A6, ObolLidoSplit: 0x2fB59065F049e0D0E3180C6312FA0FeB5Bbf0FE3, IMSCFactory: 0x49e7cA187F1E94d9A0d1DFBd6CCCd69Ca17F56a4, IMSC: 0xaF129979b773374dD3025d3F97353e73B0A6Cc8d

**Sepolia:** OWRFactory: 0xca78f8fda7ec13ae246e4d4cd38b9ce25a12e64a, OWR: 0x99585e71ab1118682d51efefca0a170c70eef0d6

## Notes

Solidity 0.8.19, Shanghai EVM, gas reports enabled, audited (https://docs.obol.tech/docs/sec/smart_contract_audit), formatting: 2-space tabs, 120 char lines, no bracket spacing

## OVM Scripts

For OVM operations (querying contracts, deploying, managing roles, distributing funds, withdrawals), use the shell scripts in `skills/obol-ovm/scripts/`. These scripts use `cast` from Foundry. Write operations require the `PRIVATE_KEY` env var to be set (scripts pass it to `cast` without reading it). See `skills/obol-ovm/SKILL.md` for full documentation.

## OVM Workflows

**Lifecycle:**
1. Deploy: `ObolValidatorManagerFactory.createObolValidatorManager(owner, beneficiary, rewardRecipient, principalThreshold)`
2. Grant roles: `grantRoles(user, DEPOSIT_ROLE | WITHDRAWAL_ROLE)`
3. Deposit: `deposit(pubkey, withdrawal_credentials, signature, deposit_data_root)` with 32 ETH
4. Distribute: `distributeFunds()` (PUSH) or `distributeFundsPull()` (PULL), then `withdrawPullBalance(account)`
5. Emergency: `sweep(address(0), 0)` extracts all principal pull balance to beneficiary

**Distribution:** If `balance - fundsPendingWithdrawal >= principalThreshold * 1e9` AND `amountOfPrincipalStake > 0`: pay principal first (up to `amountOfPrincipalStake`), overflow to reward. Else: all to reward. `amountOfPrincipalStake` decrements on payout.

**Sweep:** `sweep(address(0), amount)` anyone→principalRecipient; `sweep(customAddr, amount)` owner→custom; `sweep(address(0), 0)` sweeps all

**EIP-7002 Withdrawals:** `withdraw(pubKeys, amounts, maxFeePerWithdrawal, excessFeeRecipient)` - requires WITHDRAWAL_ROLE, ETH for `fee * pubKeys.length`

**EIP-7251 Consolidations:** `consolidate(requests, maxFeePerConsolidation, excessFeeRecipient)` - requires CONSOLIDATION_ROLE, max 63 source pubkeys per request

