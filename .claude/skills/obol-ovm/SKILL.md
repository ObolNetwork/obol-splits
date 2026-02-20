---
name: obol-ovm
description: |
  Manage Obol Validator Manager (OVM) smart contracts on Ethereum. Use this skill for any OVM operation: querying contract state, deploying new OVMs, managing roles (grant/revoke), distributing funds, setting beneficiaries or reward recipients, and requesting validator withdrawals. Trigger this skill whenever the user mentions OVM, Obol Validator Manager, validator management, distributed validators, or wants to interact with OVM contracts on mainnet/hoodi/sepolia.
---

# Obol Validator Manager (OVM) Skill

This skill provides scripts and knowledge to manage OVM contracts on Ethereum. OVM contracts manage distributed validators — handling ETH deposits, withdrawals (EIP-7002), consolidations (EIP-7251), and fund distribution to principal and reward recipients.

## Prerequisites

- **Foundry (`cast`)** must be installed and on PATH
- **Read operations** work without any keys — they use public RPCs
- **Write operations** require `PRIVATE_KEY` env var to be set by the user before running

### Environment Variables

The user sets these in their shell before running scripts:

```bash
# Required for write operations (the scripts pass this to cast, never read or log it)
export PRIVATE_KEY=0x<private_key>

# Optional: override default RPC for any network
export RPC_URL=https://your-preferred-rpc.com
```

For write operations, always confirm with the user that `PRIVATE_KEY` is set. Never attempt to read, echo, or log the key — the scripts pass it directly to `cast` as `$PRIVATE_KEY`.

## Scripts

All scripts are in `.claude/skills/obol-ovm/scripts/`. Every script accepts an optional network argument (defaults to `mainnet`). Supported networks: `mainnet`, `hoodi`, `sepolia`.

Override the default RPC by setting `RPC_URL` env var.

### Verify an Address is an OVM

Before performing write operations on an address, verify it was deployed by the factory:
```bash
.claude/skills/obol-ovm/scripts/check-is-ovm.sh <address> [network]
```
Queries `CreateObolValidatorManager` event logs from the factory. Exits 0 if the address is an OVM, exits 1 if not. Run this before grant-roles, revoke-roles, distribute, set-beneficiary, set-reward-recipient, or withdraw to catch mistakes early.

### Read Operations (no key needed)

**Query OVM state:**
```bash
.claude/skills/obol-ovm/scripts/query-ovm.sh <ovm_address> [network]
```
Returns owner, principal/reward recipients, threshold, balances, version.

**Query roles for an address:**
```bash
.claude/skills/obol-ovm/scripts/query-roles.sh <ovm_address> <target_address> [network]
```
Returns the decoded role bitmask showing which roles the target has.

**Query EIP-7002/7251 system contract fees:**
```bash
.claude/skills/obol-ovm/scripts/query-fees.sh [network]
```
Returns current withdrawal fee (EIP-7002) and consolidation fee (EIP-7251) in wei. Useful before calling withdraw or consolidate to know how much ETH to send.

You can also query OVM state directly with `cast call` for individual fields:
```bash
cast call <ovm> "owner()(address)" --rpc-url <rpc>
cast call <ovm> "principalRecipient()(address)" --rpc-url <rpc>
cast call <ovm> "rolesOf(address)(uint256)" <addr> --rpc-url <rpc>
cast balance <ovm> --rpc-url <rpc>
```

### Write Operations (require PRIVATE_KEY)

Each write script checks that `PRIVATE_KEY` is set, prints what it's about to do, then executes via `cast send`.

**Deploy a new OVM:**
```bash
.claude/skills/obol-ovm/scripts/deploy-ovm.sh <owner> <beneficiary> <reward_recipient> [threshold_gwei] [network]
```
Default threshold is 16 gwei. Deploys via the network's factory contract.

**Grant roles:**
```bash
.claude/skills/obol-ovm/scripts/grant-roles.sh <ovm_address> <target_address> <roles_value> [network]
```

**Revoke roles:**
```bash
.claude/skills/obol-ovm/scripts/revoke-roles.sh <ovm_address> <target_address> <roles_value> [network]
```

**Distribute funds:**
```bash
.claude/skills/obol-ovm/scripts/distribute-funds.sh <ovm_address> [network]
```
Anyone can call this — no special role required.

**Set beneficiary:**
```bash
.claude/skills/obol-ovm/scripts/set-beneficiary.sh <ovm_address> <new_beneficiary> [network]
```
Requires SET_BENEFICIARY_ROLE (4).

**Set reward recipient:**
```bash
.claude/skills/obol-ovm/scripts/set-reward-recipient.sh <ovm_address> <new_reward_recipient> [network]
```
Requires SET_REWARD_ROLE (16).

**Request validator withdrawal (EIP-7002):**
```bash
.claude/skills/obol-ovm/scripts/withdraw.sh <ovm_address> <pubkeys_csv> <amounts_csv> <max_fee_wei> <excess_fee_recipient> [network]
```
Requires WITHDRAWAL_ROLE (1). Sends ETH = max_fee * num_validators for fees.

**Consolidate validators (EIP-7251):**
```bash
.claude/skills/obol-ovm/scripts/consolidate.sh <ovm_address> <source_pubkey> <dest_pubkey> <max_fee_wei> <excess_fee_recipient> [network]
```
Requires CONSOLIDATION_ROLE (2). Consolidates stake from source validator into destination. Sends max_fee as ETH. Query current fees with `query-fees.sh` first.

**Deposit for validator(s):**
```bash
.claude/skills/obol-ovm/scripts/deposit.sh <ovm_address> <deposit_json_path> [network]
```
Requires DEPOSIT_ROLE (32). Reads a deposit data JSON file (standard format from deposit CLI) and executes deposits via `forge script`. Each deposit sends 32 ETH.

**Set principal stake amount:**
```bash
.claude/skills/obol-ovm/scripts/set-principal-stake.sh <ovm_address> <new_amount_wei> [network]
```
Requires owner. Sets `amountOfPrincipalStake` which controls how much of distributed funds goes to the principal recipient. Queries and prints current value before changing.

**Sweep pull balance:**
```bash
.claude/skills/obol-ovm/scripts/sweep.sh <ovm_address> <beneficiary> <amount_wei> [network]
```
Extracts funds from `pullBalances[principalRecipient]`. Pass `0x0000000000000000000000000000000000000000` as beneficiary to sweep to principal recipient (anyone can call). Pass a custom address to sweep there (owner only). Amount=0 sweeps all.

## Role System

OVM uses bitwise role flags. Add values together for multiple roles:

| Role | Value | Purpose |
|------|-------|---------|
| WITHDRAWAL_ROLE | 1 | Request validator withdrawals (EIP-7002) |
| CONSOLIDATION_ROLE | 2 | Consolidate validator stakes (EIP-7251) |
| SET_BENEFICIARY_ROLE | 4 | Change principal recipient |
| RECOVER_FUNDS_ROLE | 8 | Recover stuck funds |
| SET_REWARD_ROLE | 16 | Change reward recipient |
| DEPOSIT_ROLE | 32 | Make validator deposits |
| ALL ROLES | 63 | All of the above combined |

Example: grant WITHDRAWAL + DEPOSIT = pass `33` as the roles value.

## Factory Addresses

| Network | Factory Address |
|---------|----------------|
| mainnet | `0x2c26B5A373294CaccBd3DE817D9B7C6aea7De584` |
| hoodi | `0x5754C8665B7e7BF15E83fCdF6d9636684B782b12` |
| sepolia | `0xF32F8B563d8369d40C45D5d667C2B26937F2A3d3` |

## Default RPCs

| Network | RPC URL |
|---------|---------|
| mainnet | `https://ethereum-rpc.publicnode.com` |
| hoodi | `https://ethereum-hoodi-rpc.publicnode.com` |
| sepolia | `https://sepolia.drpc.org` |

Override any default by setting `RPC_URL` env var before running a script.

## Fund Distribution Logic

When `distributeFunds()` is called:
- If `balance - fundsPendingWithdrawal >= principalThreshold * 1e9` AND `amountOfPrincipalStake > 0`: principal gets paid first (up to `amountOfPrincipalStake`), overflow goes to reward recipient
- Otherwise: everything goes to reward recipient
- `amountOfPrincipalStake` decrements after each principal payout

## Workflow Examples

### Deploy and configure a new OVM
```
1. User sets PRIVATE_KEY env var
2. Deploy:    .claude/skills/obol-ovm/scripts/deploy-ovm.sh <owner> <beneficiary> <reward> 16 hoodi
3. Query tx receipt to get the new OVM address from logs
4. Grant roles: .claude/skills/obol-ovm/scripts/grant-roles.sh <new_ovm> <operator_addr> 33 hoodi
5. Verify:    .claude/skills/obol-ovm/scripts/query-roles.sh <new_ovm> <operator_addr> hoodi
```

### Check OVM state and distribute
```
1. Query:     .claude/skills/obol-ovm/scripts/query-ovm.sh <ovm_address> mainnet
2. If balance > 0, distribute: .claude/skills/obol-ovm/scripts/distribute-funds.sh <ovm_address> mainnet
```

### Listing OVMs on a network
Use `cast logs` against the factory to find all deployed OVMs:
```bash
cast logs --from-block <deploy_block> --to-block latest \
  --address <factory_address> \
  "CreateObolValidatorManager(address indexed,address indexed,address,address,uint64)" \
  --rpc-url <rpc>
```
Deploy blocks: mainnet=23919948, hoodi=1735335, sepolia=9159573.

## RPC Retry Rule

Public RPCs can be unreliable (timeouts, rate limits, incomplete responses). **Never treat an RPC failure as a definitive answer.** All scripts that query the chain should:

1. Retry up to **3 times** with the default public RPC before giving up
2. If all 3 attempts fail, **ask the user to provide a custom RPC** via `export RPC_URL=...` — do NOT report a false negative (e.g. saying an address is not an OVM when the RPC simply failed)
3. Exit with code `2` to distinguish RPC failures from genuine "not found" results (exit code `1`)

This rule applies to `check-is-ovm.sh` and any future scripts that depend on RPC queries for verification.

## Troubleshooting

**"PRIVATE_KEY env var must be set"** — The user needs to export their private key before write operations. Remind them: `export PRIVATE_KEY=0x...`

**RPC timeouts or errors** — Scripts retry 3 times automatically. If they still fail, ask the user for a custom RPC and set `RPC_URL` env var. Free-tier RPCs may have block range limits on log queries.

**"execution reverted"** — Check that the signer has the required role for the operation. Use `query-roles.sh` to verify permissions.

## Security

- Scripts never read, echo, or log `PRIVATE_KEY` — it's only passed as `$PRIVATE_KEY` to `cast send`
- Read operations use public RPCs with no credentials
- Always show the user what transaction will execute before running a write script
- Warn about gas costs on mainnet
