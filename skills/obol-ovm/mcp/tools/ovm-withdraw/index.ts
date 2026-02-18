/**
 * OVM Withdraw Tool - Request validator withdrawals via EIP-7002
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
} from "../../_shared/utils.js";

export const tool: Tool = {
  name: "ovm_withdraw",
  description:
    "Request validator withdrawals on an Obol Validator Manager (OVM) using EIP-7002. Requires WITHDRAWAL_ROLE and ETH for fees. Returns Cast command and encoded calldata.",
  inputSchema: {
    type: "object" as const,
    properties: {
      ovmAddress: { type: "string", description: "OVM contract address" },
      pubkeys: {
        type: "array",
        items: { type: "string" },
        description: "Validator public keys (48 bytes hex each)",
      },
      amounts: {
        type: "array",
        items: { type: "string" },
        description: "Withdrawal amounts in Gwei for each pubkey (use '0' for full exit)",
      },
      maxFeePerWithdrawal: { type: "string", description: "Maximum fee per withdrawal request in Wei" },
      excessFeeRecipient: { type: "string", description: "Address to receive excess fees" },
      network: { type: "string", enum: ["mainnet", "hoodi", "sepolia"], description: "Network (default: mainnet)" },
      rpcUrl: { type: "string", description: "Custom RPC URL" },
    },
    required: ["ovmAddress", "pubkeys", "amounts", "maxFeePerWithdrawal", "excessFeeRecipient"],
  },
};

export async function handler(args: Record<string, unknown>): Promise<string> {
  const network = (args.network as string) ?? "mainnet";
  const pubkeys = args.pubkeys as string[];
  const amounts = args.amounts as string[];

  if (!NETWORKS[network]) {
    return JSON.stringify({
      error: `Unsupported network: ${network}. Supported: ${Object.keys(NETWORKS).join(", ")}`,
    });
  }

  if (pubkeys.length !== amounts.length) {
    return JSON.stringify({
      error: `pubkeys length (${pubkeys.length}) must match amounts length (${amounts.length})`,
    });
  }

  try {
    const ovmAddress = validateAddress(args.ovmAddress as string);
    const excessFeeRecipient = validateAddress(args.excessFeeRecipient as string);
    const networkConfig = getNetworkConfig(network, args.rpcUrl as string | undefined);

    const publicClient = createPublicClientForNetwork(network, args.rpcUrl as string | undefined);
    const { isOVM: isOVMContract } = await isOVM(ovmAddress, publicClient, network);
    if (!isOVMContract) {
      return JSON.stringify({
        error: `Address ${ovmAddress} is not an Obol Validator Manager contract`,
      });
    }

    const pubkeysAsBytes = pubkeys.map((pk) =>
      pk.startsWith("0x") ? (pk as `0x${string}`) : (`0x${pk}` as `0x${string}`)
    );
    const amountsAsBigInt = amounts.map((a) => BigInt(a));
    const maxFee = BigInt(args.maxFeePerWithdrawal as string);
    const totalFee = maxFee * BigInt(pubkeys.length);

    const encodedData = encodeFunctionData({
      abi: OVMABI,
      functionName: "withdraw",
      args: [pubkeysAsBytes, amountsAsBigInt, maxFee, excessFeeRecipient],
    });

    const castCommand = `cast send ${ovmAddress} \\
  "withdraw(bytes[],uint64[],uint256,address)" \\
  "[${pubkeysAsBytes.join(",")}]" \\
  "[${amountsAsBigInt.join(",")}]" \\
  ${maxFee} \\
  ${excessFeeRecipient} \\
  --value ${totalFee} \\
  --rpc-url ${networkConfig.rpcUrl} \\
  --private-key $PRIVATE_KEY`;

    return JSON.stringify({
      operation: "withdraw",
      ovmAddress,
      validatorCount: pubkeys.length,
      pubkeys,
      amounts,
      maxFeePerWithdrawal: args.maxFeePerWithdrawal,
      totalFeeRequired: totalFee.toString(),
      excessFeeRecipient,
      transactionData: {
        to: ovmAddress,
        data: encodedData,
        value: totalFee.toString(),
        description: `Request withdrawal for ${pubkeys.length} validator(s)`,
      },
      castCommand,
      metamaskInstructions: [
        "1. Open MetaMask and click 'Send'",
        `2. To: ${ovmAddress}`,
        `3. Amount: ${totalFee} Wei (for withdrawal fees)`,
        "4. Click 'Hex' tab in the data field",
        `5. Paste: ${encodedData}`,
        "6. Confirm transaction",
      ].join("\n"),
      message: "Ready to execute. Requires WITHDRAWAL_ROLE and ETH for fees.",
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return JSON.stringify({ error: `Failed to prepare withdraw: ${message}` });
  }
}
