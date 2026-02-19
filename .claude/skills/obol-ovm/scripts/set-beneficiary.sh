#!/usr/bin/env bash
# Set a new beneficiary (principal recipient) on an OVM
# Usage: ./set-beneficiary.sh <ovm_address> <new_beneficiary> [network]
#
# Requires: SET_BENEFICIARY_ROLE (0x04) on the OVM
# Requires: PRIVATE_KEY env var set (never read or printed, only passed to cast)

set -euo pipefail

OVM="${1:?Usage: set-beneficiary.sh <ovm_address> <new_beneficiary> [network]}"
NEW_BENEFICIARY="${2:?Missing new beneficiary address}"
NETWORK="${3:-mainnet}"

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

echo "Setting beneficiary on $NETWORK..."
echo "  OVM:             $OVM"
echo "  New beneficiary: $NEW_BENEFICIARY"
echo ""

cast send "$OVM" \
  "setBeneficiary(address)" \
  "$NEW_BENEFICIARY" \
  --rpc-url "$RPC" \
  --private-key "$PRIVATE_KEY"
