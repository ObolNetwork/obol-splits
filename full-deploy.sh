# This is designed to be used to do a full deployment of the contracts on a network
# Copy .env.sample to .env and fill variables
# RUN source .env
# This script will skip a deployment if the variables are not set properly

set -e

if [[ $FEE_RECEIPIENT == "" || $FEE_SHARE == "" || $STETH_ADDRESS == "" || $WSTETH_ADDRESS == ""]] then
    echo "Skipping script/ObolLidoSplitFactoryScript deployment"
else
    forge script script/ObolLidoSplitFactoryScript.s.sol:ObolLidoSplitFactoryScript --rpc-url $RPC_URL -vv --sig "run(address,uint256,address,address)" $FEE_RECEIPIENT $FEE_SHARE $STETH_ADDRESS $WSTETH_ADDRESS --broadcast --verify
fi

if [[ $OWR_ENS_NAME == "" || $ENS_REVERSE_REGISTRAR == "" || $OWR_ENS_OWNER == "" ]] then
    echo "Skipping script/OWRFactoryScript.s.sol deployment"
else 
    forge script script/OWRFactoryScript.s.sol:OWRFactoryScript --rpc-url $RPC_URL -vv --sig "run(string,address,address)" $OWR_ENS_NAME $ENS_REVERSE_REGISTRAR $OWR_ENS_OWNER --broadcast --verify
fi

if [[ $SPLITMAIN == "" ]] then
    echo "Skipping script/IMSCFactory.s.sol:IMSCFactoryScript deployment"
else
    forge script script/IMSCFactory.s.sol:IMSCFactoryScript --rpc-url $RPC_URL -vv --sig "run(address)" $SPLITMAIN --verify --broadcast
fi
