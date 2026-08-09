# Creates an OWR around a pre-created splitter
#
# Requires the necessary split to be created, as well as a recovery address.

# Source the RPC URL, PRIVATE_KEY, and factory addresses from the .env file
source .env

# Arbitrary EOA to rescue stuck ERC20s if they are deposited on the OWR
RECOVERY_ADDRESS="0xRecoveryAddressHere"
# Address that will receive withdrawals > 16 eth (the principal)
PRINCIPAL_RECIPIENT_ADDRESS="0xCustomerAddressHere"
# Splitter created in step 1
REWARD_ADDRESS="0xCreatedSplitterHere"
# Max amount of principal to withdraw from the OWR before treating the remainder as rewards. (Currently 32k ETH)
PRINCIPAL_AMOUNT="320000000000000000000000"


# Create OWR
cast send \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  $OWR_FACTORY \
  "createOWRecipient(address,address,address,uint256)" \
  $RECOVERY_ADDRESS $PRINCIPAL_RECIPIENT_ADDRESS $REWARD_ADDRESS $PRINCIPAL_AMOUNT
