# Custom cluster scripts

There are three scripts developed to facilitate a particular cluster. 

## Data collection and preparation pre-requisites

There is key data to populate in the following locations:
- `./script/data/custom_cluster_1.json`
    - Requires 3 operator addresses
    - Requires a customer address
- `./script/data/custom_cluster_2.json`
    - Requires owners for a minimum the child-split, (but plausibly both for maximum flexibility, ownership can be revoked to make immutable). 
    - This should be a SAFE.
    - Requires 3 operators addresses
- `custom_cluster_3.sh`
    - Requires the address of the split created when running `custom_cluster_1.sh`
    - Requires a customer address
    - Requires a recovery address in case of stuck tokens

## Script pre-requisites

A `.env` file needs to be populated from `.env.deployment`. The required values for mainnet are:

```
# Private key with eth for gas costs
PRIVATE_KEY=

# Infura or other RPC URL for mainnet
RPC_URL=

# OWR Deployment
OWR_FACTORY=0x119acd7844cbdd5fc09b1c6a4408f490c8f7f522

# Splits V2 Deployments
# All chains found here: https://github.com/0xSplits/splits-contracts-monorepo/tree/main/packages/splits-v2/deployments
PULL_SPLIT_FACTORY=0x6B9118074aB15142d7524E8c4ea8f62A3Bdb98f1
PUSH_SPLIT_FACTORY=0x8E8eB0cC6AE34A38B67D5Cf91ACa38f60bc3Ecf4
```

## Next steps

Once these contracts are created. A DKG can be completed using the `charon create dkg --publish` command.