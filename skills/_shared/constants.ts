/**
 * OVM Smart Contract ABIs and Constants
 * Standalone - no external repo dependencies
 */

import { Address } from "viem";

// Role constants - bitwise flags
export const ROLES = {
  WITHDRAWAL_ROLE: 0x01,
  CONSOLIDATION_ROLE: 0x02,
  SET_BENEFICIARY_ROLE: 0x04,
  RECOVER_FUNDS_ROLE: 0x08,
  SET_REWARD_ROLE: 0x10,
  DEPOSIT_ROLE: 0x20,
} as const;

export const ALL_ROLES = 63n; // All 6 roles combined (111111 binary)

export const MAX_BLOCK_RANGE = 50000n;

// Network configurations
export interface NetworkConfig {
  name: string;
  chainId: number;
  factoryAddress: Address;
  deploymentBlock: bigint;
  launchpadUrl: string;
  rpcUrl: string;
}

export const NETWORKS: Record<string, NetworkConfig> = {
  mainnet: {
    name: "Ethereum Mainnet",
    chainId: 1,
    factoryAddress: "0x2c26B5A373294CaccBd3DE817D9B7C6aea7De584",
    deploymentBlock: 23919948n,
    launchpadUrl: "https://launchpad.obol.org",
    rpcUrl: "https://eth.llamarpc.com",
  },
  hoodi: {
    name: "Hoodi Testnet",
    chainId: 560048,
    factoryAddress: "0x5754C8665B7e7BF15E83fCdF6d9636684B782b12",
    deploymentBlock: 0n,
    launchpadUrl: "https://hoodi.launchpad.obol.org",
    rpcUrl: "https://ethereum-hoodi-rpc.publicnode.com",
  },
  sepolia: {
    name: "Sepolia Testnet",
    chainId: 11155111,
    factoryAddress: "0xF32F8B563d8369d40C45D5d667C2B26937F2A3d3",
    deploymentBlock: 9159573n,
    launchpadUrl: "https://sepolia.launchpad.obol.org",
    rpcUrl: "https://sepolia.drpc.org",
  },
};

// OVM Factory Contract ABI (minimal)
export const OVMFactoryABI = [
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: "address", name: "ovm", type: "address" },
      { indexed: true, internalType: "address", name: "owner", type: "address" },
      { indexed: false, internalType: "address", name: "beneficiary", type: "address" },
      { indexed: false, internalType: "address", name: "rewardRecipient", type: "address" },
      { indexed: false, internalType: "uint64", name: "principalThreshold", type: "uint64" },
    ],
    name: "CreateObolValidatorManager",
    type: "event",
  },
  {
    inputs: [
      { internalType: "address", name: "owner", type: "address" },
      { internalType: "address", name: "beneficiary", type: "address" },
      { internalType: "address", name: "rewardRecipient", type: "address" },
      { internalType: "uint64", name: "principalThreshold", type: "uint64" },
    ],
    name: "createObolValidatorManager",
    outputs: [
      { internalType: "contract ObolValidatorManager", name: "ovm", type: "address" },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
] as const;

// OVM Contract ABI (minimal - only functions we use)
export const OVMABI = [
  // Read functions
  {
    inputs: [],
    name: "owner",
    outputs: [{ internalType: "address", name: "result", type: "address" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "principalRecipient",
    outputs: [{ internalType: "address", name: "", type: "address" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "rewardRecipient",
    outputs: [{ internalType: "address", name: "", type: "address" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "principalThreshold",
    outputs: [{ internalType: "uint64", name: "", type: "uint64" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "fundsPendingWithdrawal",
    outputs: [{ internalType: "uint128", name: "", type: "uint128" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "amountOfPrincipalStake",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [{ internalType: "address", name: "user", type: "address" }],
    name: "rolesOf",
    outputs: [{ internalType: "uint256", name: "roles", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "version",
    outputs: [{ internalType: "string", name: "", type: "string" }],
    stateMutability: "pure",
    type: "function",
  },
  // Write functions
  {
    inputs: [
      { internalType: "address", name: "user", type: "address" },
      { internalType: "uint256", name: "roles", type: "uint256" },
    ],
    name: "grantRoles",
    outputs: [],
    stateMutability: "payable",
    type: "function",
  },
  {
    inputs: [
      { internalType: "address", name: "user", type: "address" },
      { internalType: "uint256", name: "roles", type: "uint256" },
    ],
    name: "revokeRoles",
    outputs: [],
    stateMutability: "payable",
    type: "function",
  },
  {
    inputs: [{ internalType: "address", name: "newBeneficiary", type: "address" }],
    name: "setBeneficiary",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [{ internalType: "address", name: "newRewardRecipient", type: "address" }],
    name: "setRewardRecipient",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "distributeFunds",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      { internalType: "bytes[]", name: "pubKeys", type: "bytes[]" },
      { internalType: "uint64[]", name: "amounts", type: "uint64[]" },
      { internalType: "uint256", name: "maxFeePerWithdrawal", type: "uint256" },
      { internalType: "address", name: "excessFeeRecipient", type: "address" },
    ],
    name: "withdraw",
    outputs: [],
    stateMutability: "payable",
    type: "function",
  },
  // Events
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: "address", name: "user", type: "address" },
      { indexed: true, internalType: "uint256", name: "roles", type: "uint256" },
    ],
    name: "RolesUpdated",
    type: "event",
  },
] as const;

// Role labels for display
export const ROLE_LABELS: Record<number, string> = {
  [ROLES.WITHDRAWAL_ROLE]: "WITHDRAWAL_ROLE",
  [ROLES.CONSOLIDATION_ROLE]: "CONSOLIDATION_ROLE",
  [ROLES.SET_BENEFICIARY_ROLE]: "SET_BENEFICIARY_ROLE",
  [ROLES.RECOVER_FUNDS_ROLE]: "RECOVER_FUNDS_ROLE",
  [ROLES.SET_REWARD_ROLE]: "SET_REWARD_ROLE",
  [ROLES.DEPOSIT_ROLE]: "DEPOSIT_ROLE",
};

export interface RoleStatus {
  WITHDRAWAL_ROLE: boolean;
  CONSOLIDATION_ROLE: boolean;
  SET_BENEFICIARY_ROLE: boolean;
  RECOVER_FUNDS_ROLE: boolean;
  SET_REWARD_ROLE: boolean;
  DEPOSIT_ROLE: boolean;
}

export function decodeRoles(rolesValue: bigint): RoleStatus {
  const roles = Number(rolesValue);
  return {
    WITHDRAWAL_ROLE: (roles & ROLES.WITHDRAWAL_ROLE) === ROLES.WITHDRAWAL_ROLE,
    CONSOLIDATION_ROLE: (roles & ROLES.CONSOLIDATION_ROLE) === ROLES.CONSOLIDATION_ROLE,
    SET_BENEFICIARY_ROLE: (roles & ROLES.SET_BENEFICIARY_ROLE) === ROLES.SET_BENEFICIARY_ROLE,
    RECOVER_FUNDS_ROLE: (roles & ROLES.RECOVER_FUNDS_ROLE) === ROLES.RECOVER_FUNDS_ROLE,
    SET_REWARD_ROLE: (roles & ROLES.SET_REWARD_ROLE) === ROLES.SET_REWARD_ROLE,
    DEPOSIT_ROLE: (roles & ROLES.DEPOSIT_ROLE) === ROLES.DEPOSIT_ROLE,
  };
}

export function encodeRoles(roleNames: string[]): number {
  let encoded = 0;
  for (const name of roleNames) {
    const role = ROLES[name as keyof typeof ROLES];
    if (role !== undefined) {
      encoded |= role;
    }
  }
  return encoded;
}
