"use client";
import { useState } from "react";

export default function Home() {
  const [amount, setAmount] = useState("10");
  const [side, setSide] = useState<"YES" | "NO">("YES");
  const [status, setStatus] = useState("");

  async function act(fn: "deposit" | "claim") {
    setStatus(fn === "deposit" ? `Deposit ${amount} vDOT -> ${side} ...` : "Claiming ...");
    // MVP skeleton: wire viem + wallet here (uses POOL_ABI in lib/pool.ts).
    // Until wallet is connected this is a placeholder that shows intent.
    setStatus("Wallet wiring pending — see README. Contract is live in foundry tests.");
  }

  return (
    <main style={{ maxWidth: 640, margin: "40px auto", fontFamily: "sans-serif" }}>
      <h1>Lossless Prediction Market</h1>
      <p>No-loss vToken price prediction. Principal safe, yield is the prize.</p>
      <div style={{ display: "flex", gap: 8, margin: "16px 0" }}>
        <input value={amount} onChange={(e) => setAmount(e.target.value)} placeholder="vDOT amount" />
        <select value={side} onChange={(e) => setSide(e.target.value as "YES" | "NO")}>
          <option>YES</option>
          <option>NO</option>
        </select>
        <button onClick={() => act("deposit")}>Deposit</button>
        <button onClick={() => act("claim")}>Claim</button>
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
