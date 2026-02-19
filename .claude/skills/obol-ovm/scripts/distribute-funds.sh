#!/usr/bin/env bash
# Distribute accumulated funds on an OVM to principal and reward recipients
# Usage: ./distribute-funds.sh <ovm_address> [network]
#
# Anyone can call distributeFunds() - no special role required.
#
# Requires: PRIVATE_KEY env var set (never read or printed, only passed to cast)

set -euo pipefail

OVM="${1:?Usage: distribute-funds.sh <ovm_address> [network]}"
NETWORK="${2:-mainnet}"

case "$NETWORK" in
  mainnet) DEFAULT_RPC="https://eth.llamarpc.com" ;;
  hoodi)   DEFAULT_RPC="https://ethereum-hoodi-rpc.publicnode.com" ;;
  sepolia) DEFAULT_RPC="https://sepolia.drpc.org" ;;
  *) echo "Error: unsupported network '$NETWORK'. Use: mainnet, hoodi, sepolia" >&2; exit 1 ;;
esac

RPC="${RPC_URL:-$DEFAULT_RPC}"

if [ -z "${PRIVATE_KEY:-}" ]; then
  echo "Error: PRIVATE_KEY env var must be set" >&2
  exit 1
fi

echo "Distributing funds on $NETWORK..."
echo "  OVM: $OVM"
echo ""

cast send "$OVM" \
  "distributeFunds()" \
  --rpc-url "$RPC" \
  --private-key "$PRIVATE_KEY"
