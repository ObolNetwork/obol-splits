# Obol Splits - ObolValidatorManager AI Agent Instructions

## Architecture Overview

The **ObolValidatorManager (OVM)** is the core contract for managing Ethereum validators in distributed validator clusters. Key components:

- **ObolValidatorManager** (`src/ovm/`): Main contract handling validator deposits, withdrawals, and fund distribution
- **ObolValidatorManagerFactory** (`src/ovm/`): Factory for deploying OVM instances with deterministic addresses
- **Interface** (`src/interfaces/IObolValidatorManager.sol`): Complete interface including inherited OwnableRoles + Ownable functions

## Critical Role-Based Access Control

OVM uses Solady's `OwnableRoles` with specific role constants (defined as bit flags):
```solidity
WITHDRAWAL_ROLE = 0x01        // EIP-7002 withdrawal requests
CONSOLIDATION_ROLE = 0x02     // EIP-7251 validator consolidation
SET_PRINCIPAL_ROLE = 0x04     // Change principal recipient
RECOVER_FUNDS_ROLE = 0x08     // Recover accidentally sent tokens
SET_REWARD_ROLE = 0x10        // Change reward recipient  
DEPOSIT_ROLE = 0x20           // Make validator deposits
```

## Fund Distribution Pattern

The **dual-flow architecture** is central to understanding OVM:

- **PUSH flow** (`distributeFunds()`): Immediately transfers ETH to recipients
- **PULL flow** (`distributeFundsPull()`): Sets aside funds for later withdrawal via `withdraw(account)`
- **Principal vs Reward classification**: Based on `principalThreshold` (gwei) - amounts >= threshold are principal

## Testing Patterns

Tests in `src/test/ovm/` follow specific conventions:
- Use `vm.deal()` to fund test accounts with ETH
- Mock system contracts (consolidation, withdrawal, deposit) for EIP integration testing
- Test both PUSH/PULL flows and role-based access control
- Event verification: Use `vm.recordLogs()` + `assertEq(logs.length, 0)` to verify NO events emitted
- **Event redeclaration**: Test contracts redeclare all events from interface for `vm.expectEmit()` usage

## Deployment & Scripts

Factory deployment pattern in `script/ovm/`:
- `DeployFactoryScript.s.sol`: Deploys factory with system contract addresses (EIP-7002, EIP-7251, deposit contract)
- `CreateOVMScript.s.sol`: Uses factory to create OVM instances
- **ENS Integration**: Factory supports ENS reverse registrar for human-readable names

Critical addresses (verify before deployment):
```solidity
consolidationSysContract = 0x0000BBdDc7CE488642fb579F8B00f3a590007251  // EIP-7251
withdrawalSysContract = 0x00000961Ef480Eb55e80D19ad83579A64c007002     // EIP-7002
depositSysContract = 0x00000000219ab540356cBB839Cbe05303d7705Fa        // Mainnet deposit
```

## Development Workflow

- **Build**: `forge build` (generates ABIs in `out/`)
- **Test**: `forge test --match-contract ObolValidatorManagerTest`
- **Verification**: Use `--verify` flag with forge scripts or generate Standard JSON for manual Etherscan verification
- **Gas optimization**: Contract uses `unchecked` blocks for safe arithmetic operations

## Interface Inheritance Gotchas

When implementing `IObolValidatorManager`, remember:
1. Interface includes ALL functions from OwnableRoles + Ownable + all OVM events
2. Contract must override inherited functions explicitly: `override(IObolValidatorManager, OwnableRoles)`
3. Interface inheritance order matters: `IObolValidatorManager` first, then `OwnableRoles`
4. **Events are defined in interface**: All contract events are declared in `IObolValidatorManager` interface

## Key Integration Points

- **EIP-7002**: Withdrawal system contract for validator exits
- **EIP-7251**: Consolidation system contract for merging validators  
- **Ethereum Deposit Contract**: For new validator deposits (32 ETH)
- **Solady Libraries**: OwnableRoles for access control, SafeTransferLib for ETH transfers