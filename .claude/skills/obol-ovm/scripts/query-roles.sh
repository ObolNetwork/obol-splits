#!/usr/bin/env bash
# Query roles for an address on an OVM (read-only, no private key needed)
# Usage: ./query-roles.sh <ovm_address> <target_address> [network]
#
# Returns the raw roles bitmask and decodes which roles are active.

set -euo pipefail

OVM="${1:?Usage: query-roles.sh <ovm_address> <target_address> [network]}"
TARGET="${2:?Missing target address to check roles for}"
NETWORK="${3:-mainnet}"

case "$NETWORK" in
  mainnet) DEFAULT_RPC="https://ethereum-rpc.publicnode.com" ;;
  hoodi)   DEFAULT_RPC="https://ethereum-hoodi-rpc.publicnode.com" ;;
  sepolia) DEFAULT_RPC="https://sepolia.drpc.org" ;;
  *) echo "Error: unsupported network '$NETWORK'. Use: mainnet, hoodi, sepolia" >&2; exit 1 ;;
esac

RPC="${RPC_URL:-$DEFAULT_RPC}"

echo "Querying roles for $TARGET on OVM $OVM ($NETWORK)..."
echo ""

ROLES_RAW=$(cast call "$OVM" "rolesOf(address)(uint256)" "$TARGET" --rpc-url "$RPC")
ROLES_NUM=$((ROLES_RAW))

echo "  Raw roles value: $ROLES_NUM"
echo ""
echo "  Active roles:"

if [ $((ROLES_NUM & 1)) -ne 0 ]; then echo "    - WITHDRAWAL_ROLE (1)"; fi
if [ $((ROLES_NUM & 2)) -ne 0 ]; then echo "    - CONSOLIDATION_ROLE (2)"; fi
if [ $((ROLES_NUM & 4)) -ne 0 ]; then echo "    - SET_BENEFICIARY_ROLE (4)"; fi
if [ $((ROLES_NUM & 8)) -ne 0 ]; then echo "    - RECOVER_FUNDS_ROLE (8)"; fi
if [ $((ROLES_NUM & 16)) -ne 0 ]; then echo "    - SET_REWARD_ROLE (16)"; fi
if [ $((ROLES_NUM & 32)) -ne 0 ]; then echo "    - DEPOSIT_ROLE (32)"; fi

if [ "$ROLES_NUM" -eq 0 ]; then echo "    (none)"; fi
