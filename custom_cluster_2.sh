# Requires the necessary addresses, including the SAFE that will control the split to be set in ./script/data/custom_cluster_2.json.

# Source the RPC URL, PRIVATE_KEY, and factory addresses from the .env file
source .env

# Create Nested Split
forge script script/splits/DeployScript.s.sol --sig "run(address,address,string)" \
      --rpc-url $RPC_URL --broadcast -vvv \
      $PULL_SPLIT_FACTORY $PUSH_SPLIT_FACTORY ./script/data/custom_cluster_2.json

