/**
 * OVM Distribute Tool - Distribute accumulated funds to recipients
 */

import { Tool } from "@modelcontextprotocol/sdk/types.js";
import {
  createPublicClientForNetwork,
  validateAddress,
  isOVM,
  readOVMState,
  formatOVMData,
  encodeFunctionData,
  OVMABI,
  NETWORKS,
  getNetworkConfig,
} from "../../_shared/utils.js";

export const tool: Tool = {
  name: "ovm_distribute",
  description:
    "Distribute accumulated funds on an Obol Validator Manager (OVM) to the principal and reward recipients. Funds above the principal threshold go to the beneficiary, the rest to the reward recipient. Returns Cast command and encoded calldata.",
  inputSchema: {
    type: "object" as const,
    properties: {
      ovmAddress: { type: "string", description: "OVM contract address" },
      network: { type: "string", enum: ["mainnet", "hoodi", "sepolia"], description: "Network (default: mainnet)" },
      rpcUrl: { type: "string", description: "Custom RPC URL" },
    },
    required: ["ovmAddress"],
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
    const networkConfig = getNetworkConfig(network, args.rpcUrl as string | undefined);
    const publicClient = createPublicClientForNetwork(network, args.rpcUrl as string | undefined);

    const { isOVM: isOVMContract } = await isOVM(ovmAddress, publicClient, network);
    if (!isOVMContract) {
      return JSON.stringify({
        error: `Address ${ovmAddress} is not an Obol Validator Manager contract`,
      });
    }

    const state = await readOVMState(ovmAddress, publicClient);
    const formattedState = formatOVMData(state);

    const encodedData = encodeFunctionData({
      abi: OVMABI,
      functionName: "distributeFunds",
      args: [],
    });

    const castCommand = `cast send ${ovmAddress} \\
  "distributeFunds()" \\
  --rpc-url ${networkConfig.rpcUrl} \\
  --private-key $PRIVATE_KEY`;

    return JSON.stringify({
      operation: "distributeFunds",
      ovmAddress,
      currentState: {
        balance: formattedState.balance,
        principalRecipient: state.principalRecipient,
        rewardRecipient: state.rewardRecipient,
        principalThreshold: formattedState.principalThreshold,
        fundsPendingWithdrawal: formattedState.fundsPendingWithdrawal,
        amountOfPrincipalStake: formattedState.amountOfPrincipalStake,
      },
      transactionData: {
        to: ovmAddress,
        data: encodedData,
        value: "0",
        description: "Distribute accumulated funds to principal and reward recipients",
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
      message: "Ready to distribute. Anyone can call this function.",
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return JSON.stringify({ error: `Failed to prepare distribute: ${message}` });
  }
}
