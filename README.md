# Lossless Prediction Market — No-Loss vToken Price Prediction Pool

Builder bounty submission for Bifrost (track: Lossless Prediction Market).

Users deposit vDOT/vGLMR picking YES/NO on a price round. Principal is never
at risk: only the staking yield accrued during the round is paid to the
winning side. Losers withdraw their full principal. 5% of yield goes to
treasury.

## Contracts (foundry, `src/`)

- `PredictionPool.sol` — round lifecycle: deposit / resolve / dispute /
  finalize / claim / sweep. Receipts pYES/pNO per side, pro-rata yield split.
- `ReceiptToken.sol` — minimal ERC20 receipt, pool-only mint/burn.
- `MockVToken.sol` — testnet stand-in for vDOT (open mint + accrueYield).

Guards for the pilot: round cap, deposit lock after endTime, 12h dispute
window before finalize, 30-day sweep delay for leftovers.

## Run the tests

```bash
forge test -vvv   # 7 tests, all passing
```

## Deploy (Moonbase Alpha testnet example)

```bash
forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PK --broadcast
```

Then set `NEXT_PUBLIC_POOL=<deployed>` in `ui/` and run `npm run dev`.

## UI (`ui/`)

Next.js + viem skeleton: deposit/claim buttons wired to `POOL_ABI`
(`ui/lib/pool.ts`). Wallet connection is the remaining hookup before demo.

## Milestones

- M1 (done): core pool contracts + 7 passing foundry tests.
- M2 (next): wallet wiring in UI + resolver bot + Moonbase deploy.
- M3: Moonbeam mainnet pilot with small cap, docs + forum post.
