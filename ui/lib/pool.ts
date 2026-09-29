import { parseAbi } from "viem";

export const moonbase = {
  id: 1287,
  name: "Moonbase Alpha",
  nativeCurrency: { name: "DEV", symbol: "DEV", decimals: 18 },
  rpcUrls: { default: { http: ["https://rpc.api.moonbase.moonbeam.network"] } },
} as const;

export const POOL_ABI = parseAbi([
  "function deposit(uint256 amount, bool predictYes)",
  "function claim()",
  "function resolve(bool _outcomeYes)",
  "function resolveWithPrice(uint256 price)",
  "function dispute(bool _newOutcome)",
  "function finalize()",
  "function endTime() view returns (uint256)",
  "function resolved() view returns (bool)",
  "function outcomeYes() view returns (bool)",
  "function resolvedPrice() view returns (uint256)",
  "function disputeEnd() view returns (uint256)",
  "function finalized() view returns (bool)",
  "function question() view returns (string)",
  "function strikePrice() view returns (uint256)",
  "function totalPrincipalYes() view returns (uint256)",
  "function totalPrincipalNo() view returns (uint256)",
]);

export const VTOKEN_ABI = parseAbi([
  "function approve(address spender, uint256 amount) returns (bool)",
  "function balanceOf(address a) view returns (uint256)",
  "function decimals() view returns (uint8)",
]);

export const POOL_ADDRESS = (process.env.NEXT_PUBLIC_POOL ??
  "0x0000000000000000000000000000000000000000") as `0x${string}`;

export const VTOKEN_ADDRESS = (process.env.NEXT_PUBLIC_VTOKEN ??
  "0x0000000000000000000000000000000000000000") as `0x${string}`;
