#!/usr/bin/env bash
# Query current EIP-7002 (withdrawal) and EIP-7251 (consolidation) system contract fees
# Usage: ./query-fees.sh [network]
#
# Read-only — no private key needed.
# Returns the immediate fee in wei for withdrawal and consolidation requests.

set -euo pipefail

NETWORK="${1:-mainnet}"

case "$NETWORK" in
  mainnet) DEFAULT_RPC="https://ethereum-rpc.publicnode.com" ;;
  hoodi)   DEFAULT_RPC="https://ethereum-hoodi-rpc.publicnode.com" ;;
  sepolia) DEFAULT_RPC="https://sepolia.drpc.org" ;;
  *) echo "Error: unsupported network '$NETWORK'. Use: mainnet, hoodi, sepolia" >&2; exit 1 ;;
esac

RPC="${RPC_URL:-$DEFAULT_RPC}"

# EIP-7002 withdrawal system contract
WITHDRAWAL_SYS="0x00000961Ef480Eb55e80D19ad83579A64c007002"
# EIP-7251 consolidation system contract
CONSOLIDATION_SYS="0x0000BBdDc7CE488642fb579F8B00f3a590007251"

echo "Querying system contract fees on $NETWORK..."
echo ""

WITHDRAWAL_FEE=$(cast call "$WITHDRAWAL_SYS" --rpc-url "$RPC" 2>/dev/null) || WITHDRAWAL_FEE="(unavailable)"
CONSOLIDATION_FEE=$(cast call "$CONSOLIDATION_SYS" --rpc-url "$RPC" 2>/dev/null) || CONSOLIDATION_FEE="(unavailable)"

# Convert from hex to decimal if we got valid data
if [ "$WITHDRAWAL_FEE" != "(unavailable)" ]; then
  WITHDRAWAL_FEE_DEC=$(cast to-dec "$WITHDRAWAL_FEE" 2>/dev/null || echo "$WITHDRAWAL_FEE")
  echo "  Withdrawal fee (EIP-7002):     $WITHDRAWAL_FEE_DEC wei"
else
  echo "  Withdrawal fee (EIP-7002):     (unavailable — system contract may not be deployed on $NETWORK)"
fi

if [ "$CONSOLIDATION_FEE" != "(unavailable)" ]; then
  CONSOLIDATION_FEE_DEC=$(cast to-dec "$CONSOLIDATION_FEE" 2>/dev/null || echo "$CONSOLIDATION_FEE")
  echo "  Consolidation fee (EIP-7251):  $CONSOLIDATION_FEE_DEC wei"
else
  echo "  Consolidation fee (EIP-7251):  (unavailable — system contract may not be deployed on $NETWORK)"
fi
