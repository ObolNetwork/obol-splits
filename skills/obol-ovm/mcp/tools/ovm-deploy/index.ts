/**
 * OVM Deploy Tool - Deploy new OVM contract via factory
 */

import { Tool } from "@modelcontextprotocol/sdk/types.js";
import {
  validateAddress,
  getNetworkConfig,
  encodeFunctionData,
  OVMFactoryABI,
  NETWORKS,
} from "../../_shared/utils.js";

export const tool: Tool = {
  name: "ovm_deploy",
  description:
    "Deploy a new Obol Validator Manager (OVM) contract via the factory. Returns Cast command and encoded calldata for signing.",
  inputSchema: {
    type: "object" as const,
    properties: {
      owner: { type: "string", description: "OVM owner address" },
      principalRecipient: { type: "string", description: "Principal (beneficiary) recipient address" },
      rewardRecipient: { type: "string", description: "Reward recipient address" },
      principalThreshold: { type: "number", description: "Principal threshold in Gwei (default: 16)" },
      network: { type: "string", enum: ["mainnet", "hoodi", "sepolia"], description: "Network (default: mainnet)" },
      rpcUrl: { type: "string", description: "Custom RPC URL" },
    },
    required: ["owner", "principalRecipient", "rewardRecipient"],
  },
};

export async function handler(args: Record<string, unknown>): Promise<string> {
  const network = (args.network as string) ?? "mainnet";
  const principalThreshold = (args.principalThreshold as number) ?? 16;

  if (!NETWORKS[network]) {
    return JSON.stringify({
      error: `Unsupported network: ${network}. Supported: ${Object.keys(NETWORKS).join(", ")}`,
    });
  }

  try {
    const owner = validateAddress(args.owner as string);
    const principalRecipient = validateAddress(args.principalRecipient as string);
    const rewardRecipient = validateAddress(args.rewardRecipient as string);
    const networkConfig = getNetworkConfig(network, args.rpcUrl as string | undefined);

    const encodedData = encodeFunctionData({
      abi: OVMFactoryABI,
      functionName: "createObolValidatorManager",
      args: [owner, principalRecipient, rewardRecipient, BigInt(principalThreshold)],
    });

    const castCommand = `cast send ${networkConfig.factoryAddress} \\
  "createObolValidatorManager(address,address,address,uint64)" \\
  ${owner} ${principalRecipient} ${rewardRecipient} ${principalThreshold} \\
  --rpc-url ${networkConfig.rpcUrl} \\
  --private-key $PRIVATE_KEY`;

    return JSON.stringify({
      operation: "deploy",
      network,
      factoryAddress: networkConfig.factoryAddress,
      parameters: { owner, principalRecipient, rewardRecipient, principalThreshold },
      transactionData: {
        to: networkConfig.factoryAddress,
        data: encodedData,
        value: "0",
        description: `Deploy new OVM with owner ${owner}`,
      },
      castCommand,
      metamaskInstructions: [
        "1. Open MetaMask and click 'Send'",
        `2. To: ${networkConfig.factoryAddress}`,
        "3. Amount: 0 ETH",
        "4. Click 'Hex' tab in the data field",
        `5. Paste: ${encodedData}`,
        "6. Confirm transaction",
        "7. The new OVM address will be in the transaction receipt logs",
      ].join("\n"),
      message: "Ready to deploy. Use the Cast command or MetaMask instructions above.",
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return JSON.stringify({ error: `Failed to prepare deployment: ${message}` });
  }
}
