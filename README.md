# Lossless Prediction Market — No-Loss vToken Price Prediction Pool

Builder bounty submission for Bifrost (track: Lossless Prediction Market).

Users deposit vDOT/vGLMR picking YES/NO on a price round
(e.g. "Will DOT exceed $10 at round end?"). Principal is never at risk:
only the staking yield accrued during the round is paid to the winning
side. Losers withdraw their full principal. 5% of yield goes to treasury.

## Contracts (foundry, `src/`)

- `PredictionPool.sol` — round lifecycle: deposit / resolve /
  resolveWithPrice / dispute / finalize / claim / sweep. Receipts pYES/pNO
  per side, pro-rata yield split. Outcome derived mechanically from posted
  price vs strike (`price >= strike` → YES), flippable by owner inside the
  12h dispute window.
- `ReceiptToken.sol` — minimal ERC20 receipt, pool-only mint/burn.
- `MockVToken.sol` — testnet stand-in for vDOT (open mint + accrueYield).

Guards for the pilot: round cap, deposit lock after endTime, 12h dispute
window before finalize, 30-day sweep delay for leftovers.

## Run the tests

```bash
forge test -vvv   # 8 tests, all passing
```

## Deploy (Moonbase Alpha testnet)

```bash
export RPC_URL=https://rpc.api.moonbase.moonbeam.network
forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PK --broadcast
```

Constructor args: vtoken, treasury, duration, cap, question, strikePrice
(USD 8 decimals). Get DEV for gas from the Moonbase faucet.

Then set `NEXT_PUBLIC_POOL` + `NEXT_PUBLIC_VTOKEN` in `ui/.env.local`.

## UI (`ui/`)

Next.js + viem: connect wallet (Moonbase 1287), live round state
(question, strike, pools, resolve status), deposit (approve + deposit)
and claim flows.

```bash
cd ui && npm i && npm run dev
```

## Resolver bot (`bot/`)

Posts the observed DOT price (CoinGecko) via `resolveWithPrice` after
round end, then calls `finalize` after the dispute window. Cron-safe:
exits quietly when there is nothing to do.

```bash
cd bot && cp .env.example .env && npm i && node resolve.mjs
```

Upgrade path (M3): replace owner-posted price with an on-chain oracle
(DIA/Pyth on Moonbeam).

## Milestones

- M1 (done): core pool contracts + passing foundry tests.
- M2 (done): question/strike + resolveWithPrice, wallet-wired UI, resolver bot.
- M3 (next): Moonbase deploy + demo video, then Moonbeam mainnet pilot
  with small cap, docs + forum post.
