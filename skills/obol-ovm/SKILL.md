# Obol Validator Manager (OVM) Skills

**Agent-Facing Capability Specification**

This MCP server provides conversational tools for managing Obol Validator Manager (OVM) contracts on Ethereum. An AI agent can use these tools to query, deploy, and manage OVM contracts without handling private keys.

## ⚠️ CRITICAL: Use These MCP Tools for All OVM Operations

For **ALL** OVM operations (querying contracts, deploying, managing roles, distributing funds, withdrawals):

1. **Use these MCP tools** — they are registered via `.mcp.json` in the consuming project
2. **Do NOT** use `cast`, `forge script`, or direct RPC calls for OVM interactions
3. Always check if the MCP tools (`ovm_query`, `ovm_deploy`, etc.) are available in your tool list before proceeding

### MCP Health Check

Before executing any OVM operation, verify the MCP tools are connected:

- **If MCP tools are available** (`ovm_query`, `ovm_deploy`, `ovm_grant_roles`, etc. appear in your tool list) → use them directly
- **If MCP tools are NOT available** → the server is not connected:
  1. Tell the user: *"The obol-ovm MCP server is not connected. Please reload the Cursor window (Cmd+Shift+P → 'Developer: Reload Window') or check `.mcp.json` configuration."*
  2. As a fallback, invoke the handler directly from the built dist:
     ```bash
     cd skills/obol-ovm && NODE_TLS_REJECT_UNAUTHORIZED=0 node -e \
       "require('./dist/tools/ovm-query/index.js').handler({ address: '0x...', network: 'hoodi' }).then(console.log)"
     ```
  3. If dist is missing, build first: `cd skills/obol-ovm && npm install && npm run build`

## Quick Start

### Installation
```bash
cd obol-ovm
npm install
npm run build
```

### Running the MCP Server
```bash
# Start the server
node dist/index.js

# Test with MCP inspector
npx @modelcontextprotocol/inspector node dist/index.js
```

## Available Tools

| Tool | Description | Required Permissions |
|------|-------------|---------------------|
| `ovm_query` | Query OVM state, roles, check if address is OVM, list all OVMs | None (read-only) |
| `ovm_deploy` | Deploy new OVM via factory | None (creates new contract) |
| `ovm_grant_roles` | Grant RBAC roles on an OVM | Owner |
| `ovm_revoke_roles` | Revoke RBAC roles from an OVM | Owner |
| `ovm_distribute` | Distribute accumulated funds to recipients | None (anyone can call) |
| `ovm_set_beneficiary` | Set new beneficiary (principal recipient) | SET_BENEFICIARY_ROLE |
| `ovm_set_reward_recipient` | Set new reward recipient | SET_REWARD_ROLE |
| `ovm_withdraw` | Request validator withdrawals (EIP-7002) | WITHDRAWAL_ROLE |

## How It Works

### Read Operations
- **Query tool** (`ovm_query`) reads blockchain data directly via public RPC
- No transaction signing required
- Returns JSON with contract state, roles, and metadata

### Write Operations
- **Never handle private keys** - security by design
- Return transaction data in two formats:
  1. **Cast command** - ready to copy/paste for CLI execution
  2. **Raw transaction data** - for MetaMask or other wallets
- User signs and broadcasts transactions themselves

### Network Support
All tools support three networks:
- **mainnet** - Ethereum Mainnet
- **hoodi** - Hoodi Testnet (Chain ID: 560048)
- **sepolia** - Sepolia Testnet

**Custom RPC URLs**: Every tool accepts an optional `rpcUrl` parameter. If you encounter connection issues, you can provide your own RPC endpoint:

```json
{
  "address": "0x...",
  "network": "hoodi",
  "rpcUrl": "https://your-preferred-rpc.com"
}
```

**Default RPCs** (work out of the box):
- Mainnet: `https://eth.llamarpc.com`
- Hoodi: `https://ethereum-hoodi-rpc.publicnode.com`
- Sepolia: `https://sepolia.drpc.org`

## Role-Based Access Control (RBAC)

OVM contracts use bitwise flags for roles. Each role has a specific numeric value:

| Role | Value | Capabilities |
|------|-------|-------------|
| `WITHDRAWAL_ROLE` | 1 | Request validator withdrawals (EIP-7002) |
| `CONSOLIDATION_ROLE` | 2 | Consolidate validator stakes (EIP-7251) |
| `SET_BENEFICIARY_ROLE` | 4 | Change principal recipient |
| `RECOVER_FUNDS_ROLE` | 8 | Recover stuck funds |
| `SET_REWARD_ROLE` | 16 | Change reward recipient |
| `DEPOSIT_ROLE` | 32 | Make validator deposits |

**Multiple roles** can be granted at once by adding values: `WITHDRAWAL_ROLE + DEPOSIT_ROLE = 33`

**All roles**: 1 + 2 + 4 + 8 + 16 + 32 = 63

## Example Conversation Flows

### Flow 1: Check an Address
```
User: "Check if 0xABC...123 is an OVM on mainnet"
Agent: [calls ovm_query with address and network]
Response: "Yes, this is an OVM. Owner: 0xDEF...456, Balance: 1.5 ETH..."
```

**With custom RPC:**
```
User: "Check if 0xb510537Ca215aF0a7c8A222bb14c513fA9789FF4 is an OVM on hoodi"
Agent: [calls ovm_query with { address, network: "hoodi", rpcUrl: "https://custom-rpc.com" }]
Response: "Yes, this is an OVM. Owner: 0x86B8145c..., deployed at block 1761153"
```

### Flow 2: Grant Roles
```
User: "Give withdrawal role to 0xABC...123 on that OVM"
Agent: [calls ovm_grant_roles]
Response: "Transaction ready. Here's the Cast command to sign:
  cast send 0xOVM... 'grantRoles(address,uint256)' 0xABC...123 1 --private-key $KEY"
```

### Flow 3: List All OVMs
```
User: "Show me all OVMs deployed on Hoodi"
Agent: [calls ovm_query with list=true, network=hoodi]
Response: "Found 12 OVMs:
  1. 0xABC...123 (owner: 0xDEF...456)
  2. 0xGHI...789 (owner: 0xJKL...012)
  ..."
```

### Flow 4: Deploy New OVM
```
User: "Deploy a new OVM on sepolia with beneficiary 0xABC...123"
Agent: [calls ovm_deploy with owner, beneficiary, reward recipient, network]
Response: "Transaction ready. After signing, your new OVM will be created..."
```

## OVM Detection

The tools use a reliable method to detect OVM contracts:
- Query factory's `CreateObolValidatorManager` event logs
- No false positives from random addresses
- Works across all supported networks

## Error Handling

Tools provide actionable error messages:

**Example errors:**
- `"Address is not an OVM contract"` → Suggests using `ovm_query` with `list=true`
- `"Requires owner permissions"` → Indicates which address can sign
- `"Invalid network"` → Lists supported networks

**Agent requirement (RPC issues):**
- If you encounter **any RPC connectivity/HTTP error** while querying (timeouts, TLS/SSL errors, `HttpRequestError`, DNS issues, etc.) **or** you see:
  - `Details: {"message":"ranges over 10000 blocks are not supported on freetier","code":35}`
  then you **must ask the user to provide a custom `rpcUrl`** (a Hoodi RPC that supports wider `eth_getLogs` ranges / higher limits), and retry the operation using that `rpcUrl`.

## Prerequisites & Related Tools

### Before Granting Roles
1. Use `ovm_query` to verify the address is an OVM
2. Check current roles to avoid conflicts

### After Granting Roles
1. Use `ovm_query` with `targetAddress` to verify the grant
2. Check the transaction was mined successfully

## Project Structure

```
obol-ovm/
├── SKILL.md                          # This file - agent-facing docs
├── package.json                      # Dependencies (viem, MCP SDK)
├── tsconfig.json                     # TypeScript config
├── mcp/
│   ├── index.ts                      # MCP server entry (registers all 8 tools)
│   ├── _shared/
│   │   ├── constants.ts              # ABIs, network configs, role constants
│   │   └── utils.ts                  # Blockchain client, OVM detection, state reading
│   └── tools/
│       ├── ovm-query/index.ts        # Read state + roles + list
│       ├── ovm-deploy/index.ts       # Deploy via factory
│       ├── ovm-grant-roles/index.ts  # Grant RBAC roles
│       ├── ovm-revoke-roles/index.ts # Revoke RBAC roles
│       ├── ovm-distribute/index.ts   # Distribute funds
│       ├── ovm-set-beneficiary/index.ts      # Set beneficiary
│       ├── ovm-set-reward-recipient/index.ts # Set reward recipient
│       └── ovm-withdraw/index.ts     # Request withdrawals
└── dist/                             # Compiled JavaScript (generated)
```

## Security Notes

✅ **Safe by design:**
- Never requests or stores private keys
- Read-only operations query public blockchain data
- Write operations return unsigned transaction data

⚠️ **Agent should:**
- Always display transaction data to the user before execution
- Never automatically sign/broadcast transactions
- Warn users about network gas costs

## Technical Details

**Dependencies:**
- `viem` - Type-safe Ethereum library
- `@modelcontextprotocol/sdk` - MCP protocol implementation

**Networks:**
- Mainnet factory: `0x2c26B5A373294CaccBd3DE817D9B7C6aea7De584`
- Hoodi factory: `0x5754C8665B7e7BF15E83fCdF6d9636684B782b12`
- Sepolia factory: `0xF32F8B563d8369d40C45D5d667C2B26937F2A3d3`

## For Agent Developers

### Best Practices

1. **Chain operations naturally:**
   - Query first, then act based on results
   - Verify after write operations

2. **Handle responses:**
   - Parse JSON responses
   - Extract Cast commands or transaction data
   - Present clearly to users

3. **Network context:**
   - Remember which network the user is working with
   - Default to mainnet unless specified

4. **Error recovery:**
   - Suggest alternative approaches on errors
   - Use `list=true` to discover OVMs if address unknown

### Response Formats

All tools return JSON strings. Example structures:

**Query response:**
```json
{
  "address": "0x...",
  "isOVM": true,
  "state": {
    "owner": "0x...",
    "principalRecipient": "0x...",
    "balance": "1.5 ETH"
  },
  "roles": [
    {
      "address": "0x...",
      "roles": ["WITHDRAWAL_ROLE", "DEPOSIT_ROLE"],
      "rolesValue": 33
    }
  ]
}
```

**Grant roles response:**
```json
{
  "operation": "grantRoles",
  "ovmAddress": "0x...",
  "targetAddress": "0x...",
  "roles": ["WITHDRAWAL_ROLE"],
  "rolesValue": 1,
  "castCommand": "cast send ...",
  "transactionData": {
    "to": "0x...",
    "data": "0x...",
    "value": "0"
  }
}
```

## Troubleshooting

### "Address is not an OVM contract"


### SSL Certificate Errors

The MCP server automatically handles SSL certificate issues with public RPC endpoints. If you see SSL warnings in the output, they're expected and can be ignored - queries will still work.

### Connection Timeouts

If queries time out:
- Try a different RPC endpoint using the `rpcUrl` parameter
- Check your network connectivity
- Verify the blockchain network is accessible

## Support & Resources

- **Obol Docs**: https://docs.obol.org
- **Launchpad**: https://launchpad.obol.org
- **GitHub**: https://github.com/ObolNetwork/obol-splits
- **Audits**: Available in the main repository

---

**Version**: 1.0.0  
**Last Updated**: 2026-02-18
