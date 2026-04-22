#!/usr/bin/env bash
# Consolidate validator stakes via EIP-7251
# Usage: ./consolidate.sh <ovm_address> <source_pubkey> <dest_pubkey> <max_fee_wei> <excess_fee_recipient> [network]
#
# source_pubkey: 48-byte hex pubkey of the source validator (0x-prefixed)
# dest_pubkey: 48-byte hex pubkey of the destination validator (0x-prefixed)
# max_fee_per_consolidation: in wei
# The total ETH sent = max_fee (one consolidation request)
#
# Requires: CONSOLIDATION_ROLE (0x02) on the OVM
# Requires: PRIVATE_KEY env var set (never read or printed, only passed to cast)

set -euo pipefail

OVM="${1:?Usage: consolidate.sh <ovm> <src_pubkey> <dst_pubkey> <max_fee_wei> <excess_fee_recipient> [network]}"
SRC_PUBKEY="${2:?Missing source pubkey (48 bytes hex, 0x-prefixed)}"
DST_PUBKEY="${3:?Missing destination pubkey (48 bytes hex, 0x-prefixed)}"
MAX_FEE="${4:?Missing max fee per consolidation (wei)}"
EXCESS_RECIPIENT="${5:?Missing excess fee recipient address}"
NETWORK="${6:-mainnet}"

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

echo "Consolidating validators on $NETWORK..."
echo "  OVM:               $OVM"
echo "  Source pubkey:      $SRC_PUBKEY"
echo "  Destination pubkey: $DST_PUBKEY"
echo "  Max fee:            $MAX_FEE wei"
echo "  Excess recipient:   $EXCESS_RECIPIENT"
echo ""

# consolidate(ConsolidationRequest[] requests, uint256 maxFeePerConsolidation, address excessFeeRecipient)
# ConsolidationRequest = (bytes[] srcPubKeys, bytes targetPubKey)
# We encode a single request with a single source pubkey
cast send "$OVM" \
  "consolidate((bytes[],bytes)[],uint256,address)" \
  "[([${SRC_PUBKEY}],${DST_PUBKEY})]" "$MAX_FEE" "$EXCESS_RECIPIENT" \
  --value "$MAX_FEE" \
  --rpc-url "$RPC" \
  --private-key "$PRIVATE_KEY"
