#!/usr/bin/env bash
# Deploy a new OVM contract via the factory
# Usage: ./deploy-ovm.sh <owner> <beneficiary> <reward_recipient> [principal_threshold_gwei] [network]
#
# Requires: PRIVATE_KEY env var set (never read or printed, only passed to cast)
# Requires: RPC_URL env var OR uses default for the network

set -euo pipefail

OWNER="${1:?Usage: deploy-ovm.sh <owner> <beneficiary> <reward_recipient> [threshold_gwei] [network]}"
BENEFICIARY="${2:?Missing beneficiary address}"
REWARD_RECIPIENT="${3:?Missing reward recipient address}"
THRESHOLD="${4:-16}"
NETWORK="${5:-mainnet}"

# Factory addresses per network
case "$NETWORK" in
  mainnet)   FACTORY="0x2c26B5A373294CaccBd3DE817D9B7C6aea7De584"; DEFAULT_RPC="https://ethereum-rpc.publicnode.com" ;;
  hoodi)     FACTORY="0x5754C8665B7e7BF15E83fCdF6d9636684B782b12"; DEFAULT_RPC="https://ethereum-hoodi-rpc.publicnode.com" ;;
  sepolia)   FACTORY="0xF32F8B563d8369d40C45D5d667C2B26937F2A3d3"; DEFAULT_RPC="https://sepolia.drpc.org" ;;
  *) echo "Error: unsupported network '$NETWORK'. Use: mainnet, hoodi, sepolia" >&2; exit 1 ;;
esac

RPC="${RPC_URL:-$DEFAULT_RPC}"

if [ -z "${PRIVATE_KEY:-}" ]; then
  echo "Error: PRIVATE_KEY env var must be set" >&2
  exit 1
fi

echo "Deploying OVM on $NETWORK..."
echo "  Factory:    $FACTORY"
echo "  Owner:      $OWNER"
echo "  Beneficiary: $BENEFICIARY"
echo "  Reward:     $REWARD_RECIPIENT"
echo "  Threshold:  $THRESHOLD gwei"
echo "  RPC:        $RPC"
echo ""

cast send "$FACTORY" \
  "createObolValidatorManager(address,address,address,uint64)" \
  "$OWNER" "$BENEFICIARY" "$REWARD_RECIPIENT" "$THRESHOLD" \
  --rpc-url "$RPC" \
  --private-key "$PRIVATE_KEY"
