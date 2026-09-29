export const POOL_ABI = [
  "function deposit(uint256 amount, bool predictYes)",
  "function claim()",
  "function resolve(bool outcomeYes)",
  "function finalize()",
  "function endTime() view returns (uint256)",
  "function resolved() view returns (bool)",
  "function outcomeYes() view returns (bool)",
  "function finalized() view returns (bool)",
  "function totalPrincipalYes() view returns (uint256)",
  "function totalPrincipalNo() view returns (uint256)",
] as const;

export const POOL_ADDRESS =
  (process.env.NEXT_PUBLIC_POOL as `0x${string}`) ??
  "0x0000000000000000000000000000000000000000";
