#!/usr/bin/env bash
# Request validator withdrawals via EIP-7002
# Usage: ./withdraw.sh <ovm_address> <pubkeys_comma_separated> <amounts_comma_separated> <max_fee_per_withdrawal_wei> <excess_fee_recipient> [network]
#
# pubkeys: comma-separated 48-byte hex pubkeys (0x-prefixed)
# amounts: comma-separated gwei values (use 0 for full exit)
# max_fee_per_withdrawal: in wei
# The total ETH sent = max_fee * number_of_pubkeys
#
# Requires: WITHDRAWAL_ROLE (0x01) on the OVM
# Requires: PRIVATE_KEY env var set (never read or printed, only passed to cast)

set -euo pipefail

OVM="${1:?Usage: withdraw.sh <ovm> <pubkeys> <amounts> <max_fee_wei> <excess_fee_recipient> [network]}"
PUBKEYS_CSV="${2:?Missing pubkeys (comma-separated)}"
AMOUNTS_CSV="${3:?Missing amounts (comma-separated gwei)}"
MAX_FEE="${4:?Missing max fee per withdrawal (wei)}"
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

# Count pubkeys to calculate total fee
IFS=',' read -ra PUBKEY_ARRAY <<< "$PUBKEYS_CSV"
NUM_VALIDATORS=${#PUBKEY_ARRAY[@]}
TOTAL_FEE=$((MAX_FEE * NUM_VALIDATORS))

# Format arrays for cast
PUBKEYS_ARR="[${PUBKEYS_CSV}]"
AMOUNTS_ARR="[${AMOUNTS_CSV}]"

echo "Requesting withdrawal on $NETWORK..."
echo "  OVM:        $OVM"
echo "  Validators: $NUM_VALIDATORS"
echo "  Max fee:    $MAX_FEE wei per withdrawal"
echo "  Total fee:  $TOTAL_FEE wei"
echo ""

cast send "$OVM" \
  "withdraw(bytes[],uint64[],uint256,address)" \
  "$PUBKEYS_ARR" "$AMOUNTS_ARR" "$MAX_FEE" "$EXCESS_RECIPIENT" \
  --value "$TOTAL_FEE" \
  --rpc-url "$RPC" \
  --private-key "$PRIVATE_KEY"
