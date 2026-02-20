#!/usr/bin/env bash
# Grant roles on an OVM contract
# Usage: ./grant-roles.sh <ovm_address> <target_address> <roles_value> [network]
#
# Roles (bitwise flags - add values for multiple roles):
#   WITHDRAWAL=1, CONSOLIDATION=2, SET_BENEFICIARY=4,
#   RECOVER_FUNDS=8, SET_REWARD=16, DEPOSIT=32, ALL=63
#
# Requires: PRIVATE_KEY env var set (never read or printed, only passed to cast)

set -euo pipefail

OVM="${1:?Usage: grant-roles.sh <ovm_address> <target_address> <roles_value> [network]}"
TARGET="${2:?Missing target address}"
ROLES="${3:?Missing roles value (e.g. 1 for WITHDRAWAL, 63 for ALL)}"
NETWORK="${4:-mainnet}"

case "$NETWORK" in
  mainnet) DEFAULT_RPC="https://ethereum-rpc.publicnode.com" ;;
  hoodi)   DEFAULT_RPC="https://ethereum-hoodi-rpc.publicnode.com" ;;
  sepolia) DEFAULT_RPC="https://sepolia.drpc.org" ;;
  *) echo "Error: unsupported network '$NETWORK'. Use: mainnet, hoodi, sepolia" >&2; exit 1 ;;
esac

RPC="${RPC_URL:-$DEFAULT_RPC}"

if [ -z "${PRIVATE_KEY:-}" ]; then
  echo "Error: PRIVATE_KEY env var must be set" >&2
  exit 1
fi

echo "Granting roles on $NETWORK..."
echo "  OVM:    $OVM"
echo "  Target: $TARGET"
echo "  Roles:  $ROLES"
echo ""

cast send "$OVM" \
  "grantRoles(address,uint256)" \
  "$TARGET" "$ROLES" \
  --rpc-url "$RPC" \
  --private-key "$PRIVATE_KEY"
