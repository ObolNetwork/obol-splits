/**
 * OVM Query Tool - Read OVM state, roles, and list deployed OVMs
 */

import { Tool } from "@modelcontextprotocol/sdk/types.js";
import {
  createPublicClientForNetwork,
  validateAddress,
  isOVM,
  listOVMs,
  readOVMState,
  readOVMRoles,
  formatOVMData,
  getNetworkConfig,
  NETWORKS,
} from "../_shared/utils.js";

export const tool: Tool = {
  name: "ovm_query",
  description:
    "Query Obol Validator Manager (OVM) contracts. Check if an address is an OVM, read its state (owner, recipients, balances, threshold), query roles, or list all deployed OVMs on a network.",
  inputSchema: {
    type: "object" as const,
    properties: {
      address: {
        type: "string",
        description: "OVM contract address to query (optional if using list mode)",
      },
      targetAddress: {
        type: "string",
        description: "Address to check roles for on the OVM",
      },
      network: {
        type: "string",
        enum: ["mainnet", "hoodi", "sepolia"],
        description: "Network name (default: mainnet)",
      },
      rpcUrl: {
        type: "string",
        description: "Custom RPC URL for faster queries",
      },
      list: {
        type: "boolean",
        description: "Set to true to list all deployed OVMs",
      },
    },
  },
};

export async function handler(args: Record<string, unknown>): Promise<string> {
  const network = (args.network as string) ?? "mainnet";
  const rpcUrl = args.rpcUrl as string | undefined;
  const list = args.list as boolean | undefined;
  const address = args.address as string | undefined;
  const targetAddress = args.targetAddress as string | undefined;

  if (!NETWORKS[network]) {
    return JSON.stringify({
      error: `Unsupported network: ${network}. Supported: ${Object.keys(NETWORKS).join(", ")}`,
    });
  }

  const publicClient = createPublicClientForNetwork(network, rpcUrl);
  const networkConfig = getNetworkConfig(network, rpcUrl);

  if (list) {
    try {
      const ovms = await listOVMs(publicClient, network);
      return JSON.stringify({
        network,
        totalOVMs: ovms.length,
        ovms: ovms.map((ovm) => ({
          address: ovm.ovmAddress,
          owner: ovm.owner,
          deployedAt: `Block ${ovm.blockNumber}`,
          launchpadUrl: `${networkConfig.launchpadUrl}/cluster/list?search=${ovm.ovmAddress}`,
        })),
      });
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      return JSON.stringify({ error: `Failed to list OVMs: ${message}` });
    }
  }

  if (!address) {
    return JSON.stringify({
      error: "Missing required parameter: address (or use list=true to list all OVMs)",
    });
  }

  try {
    const ovmAddress = validateAddress(address);
    const { isOVM: isOVMContract, deploymentBlock } = await isOVM(
      ovmAddress,
      publicClient,
      network
    );

    if (!isOVMContract) {
      return JSON.stringify({
        address: ovmAddress,
        isOVM: false,
        message: "This address is not an Obol Validator Manager contract",
      });
    }

    const state = await readOVMState(ovmAddress, publicClient);
    const targetAddr = targetAddress ? validateAddress(targetAddress) : undefined;
    const roles = await readOVMRoles(ovmAddress, publicClient, targetAddr);

    return JSON.stringify({
      address: ovmAddress,
      isOVM: true,
      network,
      deployedAtBlock: deploymentBlock?.toString(),
      state: formatOVMData(state),
      roles: roles.map((r) => ({
        address: r.address,
        roles: Object.entries(r.roles)
          .filter(([, hasRole]) => hasRole)
          .map(([roleName]) => roleName),
        rolesValue: r.rolesValue,
      })),
      launchpadUrl: `${networkConfig.launchpadUrl}/cluster/list?search=${ovmAddress}`,
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return JSON.stringify({ error: `Failed to query OVM: ${message}` });
  }
}
