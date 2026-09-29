// Resolver bot (M2): posts the observed DOT price to the pool after the
// round ends, then finalizes after the dispute window. Testnet only.
//
// Usage:
//   cp .env.example .env   # fill POOL_ADDRESS + PRIVATE_KEY (throwaway testnet key)
//   npm i
//   node resolve.mjs
//
// Safe to run on a cron every hour: it exits quietly when there is nothing
// to do (round live / in dispute window / already finalized).
import { createPublicClient, createWalletClient, http, parseAbi } from "viem";
import { privateKeyToAccount } from "viem/accounts";

const POOL_ABI = parseAbi([
  "function resolveWithPrice(uint256 price)",
  "function finalize()",
  "function endTime() view returns (uint256)",
  "function resolved() view returns (bool)",
  "function finalized() view returns (bool)",
  "function disputeEnd() view returns (uint256)",
  "function strikePrice() view returns (uint256)",
]);

const moonbase = {
  id: 1287,
  name: "Moonbase Alpha",
  nativeCurrency: { name: "DEV", symbol: "DEV", decimals: 18 },
  rpcUrls: { default: { http: [process.env.RPC_URL ?? "https://rpc.api.moonbase.moonbeam.network"] } },
};

const POOL = process.env.POOL_ADDRESS;
if (!POOL || !POOL.startsWith("0x")) throw new Error("POOL_ADDRESS env required");
if (!process.env.PRIVATE_KEY) throw new Error("PRIVATE_KEY env required (throwaway testnet key only)");

const account = privateKeyToAccount(process.env.PRIVATE_KEY);
const pub = createPublicClient({ chain: moonbase, transport: http() });
const wallet = createWalletClient({ account, chain: moonbase, transport: http() });

async function fetchDotPrice8() {
  const r = await fetch("https://api.coingecko.com/api/v3/simple/price?ids=polkadot&vs_currencies=usd");
  const j = await r.json();
  const usd = j?.polkadot?.usd;
  if (typeof usd !== "number") throw new Error("price feed failed: " + JSON.stringify(j).slice(0, 200));
  return BigInt(Math.round(usd * 1e8));
}

const now = BigInt(Math.floor(Date.now() / 1000));
const resolved = await pub.readContract({ address: POOL, abi: POOL_ABI, functionName: "resolved" });

if (!resolved) {
  const end = await pub.readContract({ address: POOL, abi: POOL_ABI, functionName: "endTime" });
  if (now < end) {
    console.log(`round live, ends in ${end - now}s — nothing to do`);
    process.exit(0);
  }
  const strike = await pub.readContract({ address: POOL, abi: POOL_ABI, functionName: "strikePrice" });
  const price = await fetchDotPrice8();
  console.log(`posting price ${price} (8dp) vs strike ${strike} -> ${price >= strike ? "YES" : "NO"}`);
  const hash = await wallet.writeContract({ address: POOL, abi: POOL_ABI, functionName: "resolveWithPrice", args: [price] });
  console.log("resolve tx:", hash);
} else {
  const fin = await pub.readContract({ address: POOL, abi: POOL_ABI, functionName: "finalized" });
  if (fin) {
    console.log("already finalized — nothing to do");
    process.exit(0);
  }
  const disputeEnd = await pub.readContract({ address: POOL, abi: POOL_ABI, functionName: "disputeEnd" });
  if (now < disputeEnd) {
    console.log(`in dispute window, ${disputeEnd - now}s left — nothing to do`);
    process.exit(0);
  }
  const hash = await wallet.writeContract({ address: POOL, abi: POOL_ABI, functionName: "finalize" });
  console.log("finalize tx:", hash);
}
