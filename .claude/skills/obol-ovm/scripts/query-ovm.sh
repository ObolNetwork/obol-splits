#!/usr/bin/env bash
# Query OVM contract state (read-only, no private key needed)
# Usage: ./query-ovm.sh <ovm_address> [network]
#
# Reads: owner, principalRecipient, rewardRecipient, principalThreshold,
#        fundsPendingWithdrawal, amountOfPrincipalStake, balance, version

set -euo pipefail

OVM="${1:?Usage: query-ovm.sh <ovm_address> [network]}"
NETWORK="${2:-mainnet}"

case "$NETWORK" in
  mainnet) DEFAULT_RPC="https://eth.llamarpc.com" ;;
  hoodi)   DEFAULT_RPC="https://ethereum-hoodi-rpc.publicnode.com" ;;
  sepolia) DEFAULT_RPC="https://sepolia.drpc.org" ;;
  *) echo "Error: unsupported network '$NETWORK'. Use: mainnet, hoodi, sepolia" >&2; exit 1 ;;
esac

RPC="${RPC_URL:-$DEFAULT_RPC}"

echo "Querying OVM $OVM on $NETWORK..."
echo ""

OWNER=$(cast call "$OVM" "owner()(address)" --rpc-url "$RPC")
PRINCIPAL=$(cast call "$OVM" "principalRecipient()(address)" --rpc-url "$RPC")
REWARD=$(cast call "$OVM" "rewardRecipient()(address)" --rpc-url "$RPC")
THRESHOLD=$(cast call "$OVM" "principalThreshold()(uint64)" --rpc-url "$RPC")
PENDING=$(cast call "$OVM" "fundsPendingWithdrawal()(uint128)" --rpc-url "$RPC")
STAKE=$(cast call "$OVM" "amountOfPrincipalStake()(uint256)" --rpc-url "$RPC")
BALANCE=$(cast balance "$OVM" --rpc-url "$RPC")
VERSION=$(cast call "$OVM" "version()(string)" --rpc-url "$RPC")

echo "  Owner:                    $OWNER"
echo "  Principal Recipient:      $PRINCIPAL"
echo "  Reward Recipient:         $REWARD"
echo "  Principal Threshold:      $THRESHOLD gwei"
echo "  Funds Pending Withdrawal: $PENDING wei"
echo "  Amount of Principal Stake: $STAKE wei"
echo "  Balance:                  $BALANCE"
echo "  Version:                  $VERSION"
