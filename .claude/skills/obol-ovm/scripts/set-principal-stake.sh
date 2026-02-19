#!/usr/bin/env bash
# Set the amount of principal stake on an OVM
# Usage: ./set-principal-stake.sh <ovm_address> <new_amount_wei> [network]
#
# new_amount_wei: the new principal stake amount in wei
#
# Requires: Owner of the OVM
# Requires: PRIVATE_KEY env var set (never read or printed, only passed to cast)

set -euo pipefail

OVM="${1:?Usage: set-principal-stake.sh <ovm_address> <new_amount_wei> [network]}"
NEW_AMOUNT="${2:?Missing new amount (wei)}"
NETWORK="${3:-mainnet}"

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

# Query current value before changing
CURRENT=$(cast call "$OVM" "amountOfPrincipalStake()(uint256)" --rpc-url "$RPC")

echo "Setting principal stake on $NETWORK..."
echo "  OVM:            $OVM"
echo "  Current amount: $CURRENT wei"
echo "  New amount:     $NEW_AMOUNT wei"
echo ""

cast send "$OVM" \
  "setAmountOfPrincipalStake(uint256)" \
  "$NEW_AMOUNT" \
  --rpc-url "$RPC" \
  --private-key "$PRIVATE_KEY"
