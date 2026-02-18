/**
 * OVM Grant Roles Tool - Grant RBAC roles on an OVM
 */

import { Tool } from "@modelcontextprotocol/sdk/types.js";
import {
  createPublicClientForNetwork,
  validateAddress,
  isOVM,
  encodeFunctionData,
  OVMABI,
  NETWORKS,
  encodeRoles,
  getNetworkConfig,
} from "../../_shared/utils.js";

export const tool: Tool = {
  name: "ovm_grant_roles",
  description:
    "Grant roles to an address on an Obol Validator Manager (OVM). Available roles: WITHDRAWAL_ROLE, CONSOLIDATION_ROLE, SET_BENEFICIARY_ROLE, RECOVER_FUNDS_ROLE, SET_REWARD_ROLE, DEPOSIT_ROLE. Returns Cast command and encoded calldata.",
  inputSchema: {
    type: "object" as const,
    properties: {
      ovmAddress: { type: "string", description: "OVM contract address" },
      targetAddress: { type: "string", description: "Address to grant roles to" },
      roles: {
        type: "array",
        items: { type: "string" },
        description: "Roles to grant (e.g. ['WITHDRAWAL_ROLE', 'DEPOSIT_ROLE'])",
      },
      network: { type: "string", enum: ["mainnet", "hoodi", "sepolia"], description: "Network (default: mainnet)" },
      rpcUrl: { type: "string", description: "Custom RPC URL" },
    },
    required: ["ovmAddress", "targetAddress", "roles"],
  },
};

export async function handler(args: Record<string, unknown>): Promise<string> {
  const network = (args.network as string) ?? "mainnet";

  if (!NETWORKS[network]) {
    return JSON.stringify({
      error: `Unsupported network: ${network}. Supported: ${Object.keys(NETWORKS).join(", ")}`,
    });
  }

  try {
    const ovmAddress = validateAddress(args.ovmAddress as string);
    const targetAddress = validateAddress(args.targetAddress as string);
    const networkConfig = getNetworkConfig(network, args.rpcUrl as string | undefined);

    const publicClient = createPublicClientForNetwork(network, args.rpcUrl as string | undefined);
    const { isOVM: isOVMContract } = await isOVM(ovmAddress, publicClient, network);
    if (!isOVMContract) {
      return JSON.stringify({
        error: `Address ${ovmAddress} is not an Obol Validator Manager contract`,
      });
    }

    const roles = args.roles as string[];
    const rolesValue = encodeRoles(roles);
    const encodedData = encodeFunctionData({
      abi: OVMABI,
      functionName: "grantRoles",
      args: [targetAddress, BigInt(rolesValue)],
    });

    const castCommand = `cast send ${ovmAddress} \\
  "grantRoles(address,uint256)" \\
  ${targetAddress} ${rolesValue} \\
  --rpc-url ${networkConfig.rpcUrl} \\
  --private-key $PRIVATE_KEY`;

    return JSON.stringify({
      operation: "grantRoles",
      ovmAddress,
      targetAddress,
      roles,
      rolesValue,
      transactionData: {
        to: ovmAddress,
        data: encodedData,
        value: "0",
        description: `Grant roles ${roles.join(", ")} to ${targetAddress}`,
      },
      castCommand,
      metamaskInstructions: [
        "1. Open MetaMask and click 'Send'",
        `2. To: ${ovmAddress}`,
        "3. Amount: 0 ETH",
        "4. Click 'Hex' tab in the data field",
        `5. Paste: ${encodedData}`,
        "6. Confirm transaction",
      ].join("\n"),
      message: "Ready to execute. Requires owner permissions on the OVM.",
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return JSON.stringify({ error: `Failed to prepare grant roles: ${message}` });
  }
}
