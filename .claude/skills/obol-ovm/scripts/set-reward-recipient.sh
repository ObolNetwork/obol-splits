#!/usr/bin/env bash
# Set a new reward recipient on an OVM
# Usage: ./set-reward-recipient.sh <ovm_address> <new_reward_recipient> [network]
#
# Requires: SET_REWARD_ROLE (0x10) on the OVM
# Requires: PRIVATE_KEY env var set (never read or printed, only passed to cast)

set -euo pipefail

OVM="${1:?Usage: set-reward-recipient.sh <ovm_address> <new_reward_recipient> [network]}"
NEW_REWARD="${2:?Missing new reward recipient address}"
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

echo "Setting reward recipient on $NETWORK..."
echo "  OVM:              $OVM"
echo "  New reward recip: $NEW_REWARD"
echo ""

cast send "$OVM" \
  "setRewardRecipient(address)" \
  "$NEW_REWARD" \
  --rpc-url "$RPC" \
  --private-key "$PRIVATE_KEY"
