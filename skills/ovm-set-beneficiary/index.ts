/**
 * OVM Set Beneficiary Tool - Update the principal recipient on an OVM
 */

import { Tool } from "@modelcontextprotocol/sdk/types.js";
import {
  createPublicClientForNetwork,
  validateAddress,
  isOVM,
  encodeFunctionData,
  OVMABI,
  NETWORKS,
  getNetworkConfig,
} from "../_shared/utils.js";

export const tool: Tool = {
  name: "ovm_set_beneficiary",
  description:
    "Set a new beneficiary (principal recipient) on an Obol Validator Manager (OVM). Requires SET_BENEFICIARY_ROLE. Returns Cast command and encoded calldata.",
  inputSchema: {
    type: "object" as const,
    properties: {
      ovmAddress: { type: "string", description: "OVM contract address" },
      newBeneficiary: { type: "string", description: "New beneficiary address" },
      network: { type: "string", enum: ["mainnet", "hoodi", "sepolia"], description: "Network (default: mainnet)" },
      rpcUrl: { type: "string", description: "Custom RPC URL" },
    },
    required: ["ovmAddress", "newBeneficiary"],
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
    const newBeneficiary = validateAddress(args.newBeneficiary as string);
    const networkConfig = getNetworkConfig(network, args.rpcUrl as string | undefined);

    const publicClient = createPublicClientForNetwork(network, args.rpcUrl as string | undefined);
    const { isOVM: isOVMContract } = await isOVM(ovmAddress, publicClient, network);
    if (!isOVMContract) {
      return JSON.stringify({
        error: `Address ${ovmAddress} is not an Obol Validator Manager contract`,
      });
    }

    const encodedData = encodeFunctionData({
      abi: OVMABI,
      functionName: "setBeneficiary",
      args: [newBeneficiary],
    });

    const castCommand = `cast send ${ovmAddress} \\
  "setBeneficiary(address)" \\
  ${newBeneficiary} \\
  --rpc-url ${networkConfig.rpcUrl} \\
  --private-key $PRIVATE_KEY`;

    return JSON.stringify({
      operation: "setBeneficiary",
      ovmAddress,
      newBeneficiary,
      transactionData: {
        to: ovmAddress,
        data: encodedData,
        value: "0",
        description: `Set beneficiary to ${newBeneficiary}`,
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
      message: "Ready to execute. Requires SET_BENEFICIARY_ROLE.",
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return JSON.stringify({ error: `Failed to prepare set beneficiary: ${message}` });
  }
}
