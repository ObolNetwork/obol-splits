#!/usr/bin/env bash
# Deposit ETH for validator(s) via OVM using forge script
# Usage: ./deposit.sh <ovm_address> <deposit_json_path> [network]
#
# deposit_json_path: path to a deposit data JSON file (array of deposit entries)
#   Each entry must have: pubkey, withdrawal_credentials, signature, deposit_data_root, amount (in gwei)
#
# This script uses `forge script` because the deposit data JSON parsing is
# complex (multiple fields per entry, loops). The Foundry script at
# script/ovm/DepositScript.s.sol handles this natively.
#
# Requires: DEPOSIT_ROLE (0x20) on the OVM
# Requires: PRIVATE_KEY env var set (never read or printed, only passed to forge)

set -euo pipefail

OVM="${1:?Usage: deposit.sh <ovm_address> <deposit_json_path> [network]}"
DEPOSIT_FILE="${2:?Missing deposit data JSON file path}"
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

if [ ! -f "$DEPOSIT_FILE" ]; then
  echo "Error: deposit data file not found: $DEPOSIT_FILE" >&2
  exit 1
fi

echo "Depositing validators on $NETWORK..."
echo "  OVM:          $OVM"
echo "  Deposit file: $DEPOSIT_FILE"
echo ""

forge script script/ovm/DepositScript.s.sol \
  --sig "run(address,string)" "$OVM" "$DEPOSIT_FILE" \
  --rpc-url "$RPC" \
  --private-key "$PRIVATE_KEY" \
  --broadcast
