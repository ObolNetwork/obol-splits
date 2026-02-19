#!/usr/bin/env bash
# Check if an address is an OVM contract by querying factory deployment logs
# Usage: ./check-is-ovm.sh <address> [network]
#
# Queries CreateObolValidatorManager events from the factory contract.
# Handles RPC block range limits by chunking queries (newest blocks first).
# Exits 0 if the address is an OVM, exits 1 if not, exits 2 if RPC failed.

set -euo pipefail

ADDRESS="$(echo "${1:?Usage: check-is-ovm.sh <address> [network]}" | tr '[:upper:]' '[:lower:]')"
NETWORK="${2:-mainnet}"

case "$NETWORK" in
  mainnet) FACTORY="0x2c26B5A373294CaccBd3DE817D9B7C6aea7De584"; DEPLOY_BLOCK=23919948; DEFAULT_RPC="https://ethereum-rpc.publicnode.com" ;;
  hoodi)   FACTORY="0x5754C8665B7e7BF15E83fCdF6d9636684B782b12"; DEPLOY_BLOCK=1735335;  DEFAULT_RPC="https://ethereum-hoodi-rpc.publicnode.com" ;;
  sepolia) FACTORY="0xF32F8B563d8369d40C45D5d667C2B26937F2A3d3"; DEPLOY_BLOCK=9159573;  DEFAULT_RPC="https://sepolia.drpc.org" ;;
  *) echo "Error: unsupported network '$NETWORK'. Use: mainnet, hoodi, sepolia" >&2; exit 1 ;;
esac

RPC="${RPC_URL:-$DEFAULT_RPC}"
CHUNK_SIZE=50000
MAX_RETRIES=3

echo "Checking if $ADDRESS is an OVM on $NETWORK..."

# Event: CreateObolValidatorManager(address indexed ovm, address indexed owner, address beneficiary, address rewardRecipient, uint64 principalThreshold)
TOPIC0="$(cast keccak 'CreateObolValidatorManager(address,address,address,address,uint64)')"
PADDED_ADDR="0x000000000000000000000000${ADDRESS#0x}"

# Get current block number
LATEST_BLOCK=$(cast block-number --rpc-url "$RPC" 2>&1) || {
  echo "Error: Could not fetch latest block number from RPC" >&2
  echo "Please set a custom RPC: export RPC_URL=https://your-rpc-url" >&2
  exit 2
}

# Query in chunks from newest to oldest (most recent deployments queried first)
TO_BLOCK=$LATEST_BLOCK
while [ "$TO_BLOCK" -ge "$DEPLOY_BLOCK" ]; do
  FROM_BLOCK=$((TO_BLOCK - CHUNK_SIZE + 1))
  if [ "$FROM_BLOCK" -lt "$DEPLOY_BLOCK" ]; then
    FROM_BLOCK=$DEPLOY_BLOCK
  fi

  for ATTEMPT in $(seq 1 $MAX_RETRIES); do
    LOGS=$(cast logs \
      --from-block "$FROM_BLOCK" \
      --to-block "$TO_BLOCK" \
      --address "$FACTORY" \
      "$TOPIC0" \
      "$PADDED_ADDR" \
      --rpc-url "$RPC" 2>&1)
    EXIT_CODE=$?

    # Found matching logs — it's an OVM
    if echo "$LOGS" | grep -qi "topic"; then
      echo "Yes — $ADDRESS is an OVM deployed by factory $FACTORY"
      exit 0
    fi

    # cast succeeded without errors — this chunk has no match, move to next
    if [ $EXIT_CODE -eq 0 ] && ! echo "$LOGS" | grep -qi "error\|timeout\|rate.limit\|failed\|connection\|block range"; then
      break
    fi

    # RPC failed — retry this chunk
    if [ "$ATTEMPT" -lt "$MAX_RETRIES" ]; then
      echo "RPC failed on blocks $FROM_BLOCK-$TO_BLOCK (attempt $ATTEMPT/$MAX_RETRIES), retrying..." >&2
      sleep 2
    elif [ "$ATTEMPT" -eq "$MAX_RETRIES" ]; then
      echo "" >&2
      echo "Error: Failed to query blocks $FROM_BLOCK-$TO_BLOCK after $MAX_RETRIES attempts." >&2
      echo "The public RPC may be unreliable. Please set a custom RPC and retry:" >&2
      echo "  export RPC_URL=https://your-rpc-url" >&2
      echo "  $0 $*" >&2
      exit 2
    fi
  done

  TO_BLOCK=$((FROM_BLOCK - 1))
done

# All chunks queried, no match found
echo "No — $ADDRESS is NOT an OVM on $NETWORK"
exit 1
