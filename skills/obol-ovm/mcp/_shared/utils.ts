/**
 * Blockchain utilities for OVM skills
 */

import {
  createPublicClient,
  http,
  Address,
  PublicClient,
  parseAbiItem,
  formatEther,
  formatUnits,
  isAddress as viemIsAddress,
  encodeFunctionData,
} from "viem";
import { mainnet, sepolia } from "viem/chains";
import { defineChain } from "viem";
import {
  NETWORKS,
  NetworkConfig,
  OVMABI,
  OVMFactoryABI,
  MAX_BLOCK_RANGE,
  decodeRoles,
  RoleStatus,
  ALL_ROLES,
} from "./constants.js";

const hoodi = defineChain({
  id: 560048,
  name: "Hoodi",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://ethereum-hoodi-rpc.publicnode.com"] },
  },
  blockExplorers: {
    default: { name: "Hoodi Explorer", url: "https://explorer.hoodi.io" },
  },
  testnet: true,
});

const CHAINS = {
  mainnet,
  hoodi,
  sepolia,
} as const;

/**
 * Get network configuration, optionally overriding RPC URL
 */
export function getNetworkConfig(
  network: string = "mainnet",
  customRpcUrl?: string
): NetworkConfig {
  const config = NETWORKS[network];
  if (!config) {
    throw new Error(
      `Unsupported network: ${network}. Supported: ${Object.keys(NETWORKS).join(", ")}`
    );
  }
  if (customRpcUrl) {
    return { ...config, rpcUrl: customRpcUrl };
  }
  return config;
}

/**
 * Create viem public client for reading blockchain data
 * Now with better timeouts and reliable default RPCs
 */
export function createPublicClientForNetwork(
  network: string = "mainnet",
  customRpcUrl?: string
): PublicClient {
  const config = getNetworkConfig(network, customRpcUrl);
  const chain = CHAINS[network as keyof typeof CHAINS];

  return createPublicClient({
    chain,
    transport: http(config.rpcUrl, {
      retryCount: 3,
      timeout: 15_000,
    }),
  }) as PublicClient;
}

/**
 * Validate Ethereum address
 */
export function validateAddress(address: string): Address {
  if (!viemIsAddress(address)) {
    throw new Error(`Invalid Ethereum address: ${address}`);
  }
  return address as Address;
}

/**
 * Check if an address is an OVM contract by querying factory deployment logs
 */
export async function isOVM(
  address: Address,
  publicClient: PublicClient,
  network: string = "mainnet"
): Promise<{ isOVM: boolean; deploymentBlock?: bigint }> {
  try {
    const networkConfig = getNetworkConfig(network);
    const latestBlock = await publicClient.getBlockNumber();
    let fromBlock = networkConfig.deploymentBlock;

    while (fromBlock <= latestBlock) {
      const toBlock =
        fromBlock + MAX_BLOCK_RANGE > latestBlock
          ? latestBlock
          : fromBlock + MAX_BLOCK_RANGE;

      const logs = await publicClient.getLogs({
        address: networkConfig.factoryAddress,
        event: parseAbiItem(
          "event CreateObolValidatorManager(address indexed ovm, address indexed owner, address beneficiary, address rewardRecipient, uint64 principalThreshold)"
        ),
        fromBlock,
        toBlock,
      });

      for (const log of logs) {
        const logArgs = log.args as { ovm?: Address };
        if (logArgs?.ovm?.toLowerCase() === address.toLowerCase()) {
          return { isOVM: true, deploymentBlock: log.blockNumber };
        }
      }

      fromBlock = toBlock + 1n;
    }
  } catch (error) {
    console.error("Error querying factory logs:", error);
  }

  return { isOVM: false };
}

/**
 * List all deployed OVMs from factory events
 */
export async function listOVMs(
  publicClient: PublicClient,
  network: string = "mainnet"
): Promise<Array<{ ovmAddress: Address; owner: Address; blockNumber: bigint }>> {
  const networkConfig = getNetworkConfig(network);
  const latestBlock = await publicClient.getBlockNumber();
  let fromBlock = networkConfig.deploymentBlock;
  const ovms: Array<{ ovmAddress: Address; owner: Address; blockNumber: bigint }> = [];

  while (fromBlock <= latestBlock) {
    const toBlock =
      fromBlock + MAX_BLOCK_RANGE > latestBlock
        ? latestBlock
        : fromBlock + MAX_BLOCK_RANGE;

    const logs = await publicClient.getLogs({
      address: networkConfig.factoryAddress,
      event: parseAbiItem(
        "event CreateObolValidatorManager(address indexed ovm, address indexed owner, address beneficiary, address rewardRecipient, uint64 principalThreshold)"
      ),
      fromBlock,
      toBlock,
    });

    for (const log of logs) {
      const args = log.args as { ovm?: Address; owner?: Address };
      if (args?.ovm && args?.owner) {
        ovms.push({
          ovmAddress: args.ovm,
          owner: args.owner,
          blockNumber: log.blockNumber ?? 0n,
        });
      }
    }

    fromBlock = toBlock + 1n;
  }

  return ovms;
}

/**
 * Read complete OVM contract state
 */
export async function readOVMState(
  ovmAddress: Address,
  publicClient: PublicClient
): Promise<{
  owner: Address;
  principalRecipient: Address;
  rewardRecipient: Address;
  principalThreshold: number;
  fundsPendingWithdrawal: string;
  amountOfPrincipalStake: string;
  balance: string;
  version: string;
}> {
  const [
    owner,
    principalRecipient,
    rewardRecipient,
    principalThreshold,
    fundsPendingWithdrawal,
    amountOfPrincipalStake,
    balance,
    version,
  ] = await Promise.all([
    publicClient.readContract({
      address: ovmAddress,
      abi: OVMABI,
      functionName: "owner",
    }),
    publicClient.readContract({
      address: ovmAddress,
      abi: OVMABI,
      functionName: "principalRecipient",
    }),
    publicClient.readContract({
      address: ovmAddress,
      abi: OVMABI,
      functionName: "rewardRecipient",
    }),
    publicClient.readContract({
      address: ovmAddress,
      abi: OVMABI,
      functionName: "principalThreshold",
    }),
    publicClient.readContract({
      address: ovmAddress,
      abi: OVMABI,
      functionName: "fundsPendingWithdrawal",
    }),
    publicClient.readContract({
      address: ovmAddress,
      abi: OVMABI,
      functionName: "amountOfPrincipalStake",
    }),
    publicClient.getBalance({ address: ovmAddress }),
    publicClient.readContract({
      address: ovmAddress,
      abi: OVMABI,
      functionName: "version",
    }),
  ]);

  return {
    owner: owner as Address,
    principalRecipient: principalRecipient as Address,
    rewardRecipient: rewardRecipient as Address,
    principalThreshold: Number(formatUnits(BigInt(principalThreshold as bigint), 9)),
    fundsPendingWithdrawal: formatEther(BigInt(fundsPendingWithdrawal as bigint)),
    amountOfPrincipalStake: formatEther(BigInt(amountOfPrincipalStake as bigint)),
    balance: formatEther(balance),
    version: version as string,
  };
}

/**
 * Read roles for addresses on an OVM.
 * If targetAddress provided, returns roles for that address only.
 * Otherwise queries RolesUpdated events to find all role holders.
 */
export async function readOVMRoles(
  ovmAddress: Address,
  publicClient: PublicClient,
  targetAddress?: Address
): Promise<Array<{ address: Address; roles: RoleStatus; rolesValue: number }>> {
  if (targetAddress) {
    const rolesValue = (await publicClient.readContract({
      address: ovmAddress,
      abi: OVMABI,
      functionName: "rolesOf",
      args: [targetAddress],
    })) as bigint;

    return [
      {
        address: targetAddress,
        roles: decodeRoles(rolesValue),
        rolesValue: Number(rolesValue),
      },
    ];
  }

  const latestBlock = await publicClient.getBlockNumber();
  let fromBlock = 0n;
  const uniqueAddresses = new Set<Address>();

  while (fromBlock <= latestBlock) {
    const toBlock =
      fromBlock + MAX_BLOCK_RANGE > latestBlock
        ? latestBlock
        : fromBlock + MAX_BLOCK_RANGE;

    const logs = await publicClient.getLogs({
      address: ovmAddress,
      event: parseAbiItem(
        "event RolesUpdated(address indexed user, uint256 indexed roles)"
      ),
      fromBlock,
      toBlock,
    });

    for (const log of logs) {
      const args = log.args as { user?: Address };
      if (args?.user) {
        uniqueAddresses.add(args.user);
      }
    }

    fromBlock = toBlock + 1n;
  }

  const results = await Promise.all(
    Array.from(uniqueAddresses).map(async (addr) => {
      const rolesValue = (await publicClient.readContract({
        address: ovmAddress,
        abi: OVMABI,
        functionName: "rolesOf",
        args: [addr],
      })) as bigint;

      return {
        address: addr,
        roles: decodeRoles(rolesValue),
        rolesValue: Number(rolesValue),
      };
    })
  );

  // Include owner with ALL_ROLES if not already in results
  const owner = (await publicClient.readContract({
    address: ovmAddress,
    abi: OVMABI,
    functionName: "owner",
  })) as Address;

  const ownerIncluded = results.some(
    (r) => r.address.toLowerCase() === owner.toLowerCase()
  );

  if (!ownerIncluded) {
    results.unshift({
      address: owner,
      roles: decodeRoles(ALL_ROLES),
      rolesValue: Number(ALL_ROLES),
    });
  }

  return results;
}

/**
 * Format OVM state data for display with units
 */
export function formatOVMData(state: Awaited<ReturnType<typeof readOVMState>>) {
  return {
    ...state,
    principalThreshold: `${state.principalThreshold} Gwei`,
    fundsPendingWithdrawal: `${state.fundsPendingWithdrawal} ETH`,
    amountOfPrincipalStake: `${state.amountOfPrincipalStake} ETH`,
    balance: `${state.balance} ETH`,
  };
}

// Re-export encodeFunctionData for skill use
export { encodeFunctionData, type Address } from "viem";
export { OVMABI, OVMFactoryABI, NETWORKS, encodeRoles, ROLES } from "./constants.js";
