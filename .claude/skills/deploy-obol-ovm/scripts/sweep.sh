#!/usr/bin/env bash
# Sweep pull balance from an OVM
# Usage: ./sweep.sh <ovm_address> <beneficiary> <amount_wei> [network]
#
# beneficiary: address(0) → sweeps to principal recipient (anyone can call)
#              custom addr → sweeps to that address (owner only)
# amount: 0 → sweep ALL available pull balance
#         >0 → sweep specific amount in wei
#
# Requires: PRIVATE_KEY env var set (never read or printed, only passed to cast)

set -euo pipefail

OVM="${1:?Usage: sweep.sh <ovm_address> <beneficiary> <amount_wei> [network]}"
BENEFICIARY="${2:?Missing beneficiary (use 0x0000000000000000000000000000000000000000 for principal recipient)}"
AMOUNT="${3:?Missing amount in wei (use 0 to sweep all)}"
NETWORK="${4:-mainnet}"

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

# Query current state before sweep
PRINCIPAL_RECIPIENT=$(cast call "$OVM" "getBeneficiary()(address)" --rpc-url "$RPC")
PULL_BALANCE=$(cast call "$OVM" "getPullBalance(address)(uint256)" "$PRINCIPAL_RECIPIENT" --rpc-url "$RPC")
PENDING=$(cast call "$OVM" "fundsPendingWithdrawal()(uint128)" --rpc-url "$RPC")

echo "Sweeping on $NETWORK..."
echo "  OVM:                  $OVM"
echo "  Principal recipient:  $PRINCIPAL_RECIPIENT"
echo "  Pull balance:         $PULL_BALANCE wei"
echo "  Funds pending:        $PENDING wei"

if [ "$BENEFICIARY" = "0x0000000000000000000000000000000000000000" ]; then
  echo "  Sweep to:             principal recipient (anyone can call)"
else
  echo "  Sweep to:             $BENEFICIARY (owner only)"
fi

if [ "$AMOUNT" = "0" ]; then
  echo "  Amount:               ALL available pull balance"
else
  echo "  Amount:               $AMOUNT wei"
fi
echo ""

cast send "$OVM" \
  "sweep(address,uint256)" \
  "$BENEFICIARY" "$AMOUNT" \
  --rpc-url "$RPC" \
  --private-key "$PRIVATE_KEY"
