"use client";
import { useEffect, useState } from "react";
import {
  createPublicClient,
  createWalletClient,
  custom,
  http,
  formatUnits,
  parseUnits,
} from "viem";
import {
  POOL_ABI,
  POOL_ADDRESS,
  VTOKEN_ABI,
  VTOKEN_ADDRESS,
  activeChain,
} from "../lib/pool";

function pub() {
  return createPublicClient({ chain: activeChain, transport: http() });
}

export default function Home() {
  const [account, setAccount] = useState<`0x${string}` | null>(null);
  const [amount, setAmount] = useState("10");
  const [side, setSide] = useState<"YES" | "NO">("YES");
  const [status, setStatus] = useState("");
  const [info, setInfo] = useState<any>(null);

  async function load() {
    if (POOL_ADDRESS === "0x0000000000000000000000000000000000000000") {
      setStatus("Set NEXT_PUBLIC_POOL in ui/.env.local first (deployed pool address).");
      return;
    }
    const c = pub();
    const [
      question, strike, end, resolved, outYes, finalized, totY, totN,
    ] = await Promise.all([
      c.readContract({ address: POOL_ADDRESS, abi: POOL_ABI, functionName: "question" }),
      c.readContract({ address: POOL_ADDRESS, abi: POOL_ABI, functionName: "strikePrice" }),
      c.readContract({ address: POOL_ADDRESS, abi: POOL_ABI, functionName: "endTime" }),
      c.readContract({ address: POOL_ADDRESS, abi: POOL_ABI, functionName: "resolved" }),
      c.readContract({ address: POOL_ADDRESS, abi: POOL_ABI, functionName: "outcomeYes" }),
      c.readContract({ address: POOL_ADDRESS, abi: POOL_ABI, functionName: "finalized" }),
      c.readContract({ address: POOL_ADDRESS, abi: POOL_ABI, functionName: "totalPrincipalYes" }),
      c.readContract({ address: POOL_ADDRESS, abi: POOL_ABI, functionName: "totalPrincipalNo" }),
    ]);
    setInfo({ question, strike, end, resolved, outYes, finalized, totY, totN });
  }

  useEffect(() => {
    load();
  }, []);

  async function connect() {
    const eth = (window as any).ethereum;
    if (!eth) {
      setStatus(`No wallet found. Install MetaMask with ${activeChain.name} (chain ${activeChain.id}).`);
      return;
    }
    const wallet = createWalletClient({ chain: activeChain, transport: custom(eth) });
    const [addr] = await wallet.requestAddresses();
    setAccount(addr);
    setStatus(`Connected ${addr}`);
    try {
      await eth.request({
        method: "wallet_switchEthereumChain",
        params: [{ chainId: `0x${activeChain.id.toString(16)}` }],
      });
    } catch (e: any) {
      setStatus(`Connected ${addr}. Please switch wallet to ${activeChain.name} (chain ${activeChain.id}).`);
    }
  }

  async function wallet() {
    const eth = (window as any).ethereum;
    if (!eth || !account) throw new Error("connect wallet first");
    return createWalletClient({ account, chain: activeChain, transport: custom(eth) });
  }

  async function deposit() {
    try {
      const w = await wallet();
      const amt = parseUnits(amount, 18);
      setStatus("1/2 approving vToken...");
      await w.writeContract({ address: VTOKEN_ADDRESS, abi: VTOKEN_ABI, functionName: "approve", args: [POOL_ADDRESS, amt] });
      setStatus("2/2 depositing...");
      const h = await w.writeContract({
        address: POOL_ADDRESS, abi: POOL_ABI, functionName: "deposit", args: [amt, side === "YES"],
      });
      setStatus(`Deposited. tx ${h}`);
      load();
    } catch (e: any) {
      setStatus(`Deposit failed: ${e?.shortMessage ?? e?.message ?? e}`);
    }
  }

  async function claim() {
    try {
      const w = await wallet();
      setStatus("Claiming...");
      const h = await w.writeContract({ address: POOL_ADDRESS, abi: POOL_ABI, functionName: "claim" });
      setStatus(`Claimed. tx ${h}`);
      load();
    } catch (e: any) {
      setStatus(`Claim failed: ${e?.shortMessage ?? e?.message ?? e}`);
    }
  }

  return (
    <main style={{ maxWidth: 680, margin: "40px auto", fontFamily: "sans-serif", padding: 16 }}>
      <h1>Lossless Prediction Market</h1>
      <p>No-loss vToken price prediction. Principal safe, yield is the prize.</p>
      {!account ? (
        <button onClick={connect}>Connect wallet ({activeChain.name} {activeChain.id})</button>
      ) : (
        <p>Wallet: {account}</p>
      )}
      {info && (
        <div style={{ border: "1px solid #ccc", padding: 12, margin: "16px 0" }}>
          <p><b>Q:</b> {String(info.question)}</p>
          <p>Strike: ${Number(formatUnits(info.strike as bigint, 8))} | YES pool: {formatUnits(info.totY as bigint, 18)} vDOT | NO pool: {formatUnits(info.totN as bigint, 18)} vDOT</p>
          <p>Round ends: {new Date(Number(info.end) * 1000).toLocaleString()} | Resolved: {String(info.resolved)}{info.resolved ? ` (${info.outYes ? "YES" : "NO"})` : ""} | Finalized: {String(info.finalized)}</p>
        </div>
      )}
      <div style={{ display: "flex", gap: 8, margin: "16px 0" }}>
        <input value={amount} onChange={(e) => setAmount(e.target.value)} placeholder="vDOT amount" />
        <select value={side} onChange={(e) => setSide(e.target.value as "YES" | "NO")}>
          <option>YES</option>
          <option>NO</option>
        </select>
        <button onClick={deposit}>Deposit</button>
        <button onClick={claim}>Claim</button>
      </div>
      <p>{status}</p>
      <h3>How it works</h3>
      <ol>
        <li>Deposit vDOT on YES or NO before round end.</li>
        <li>Pool earns staking yield during the round.</li>
        <li>Winners split the yield. Losers withdraw principal in full.</li>
      </ol>
    </main>
  );
}
