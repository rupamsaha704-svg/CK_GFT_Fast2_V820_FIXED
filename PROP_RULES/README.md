# Prop Firm Rules Library

Permanent, per-firm reference of the rules we have **confirmed** — so we never have to
re-research "what was that firm's daily rule / EA policy / weekend rule" again.

- **Sources:** only PRIMARY ones — each firm's own help-centre/terms page, or a written
  support reply. Third-party blogs are used only as pointers, never as the final word.
- **Format:** Markdown (renders directly on GitHub; export to PDF via the browser Print
  dialog if a file is needed).
- **Master registry (all firms, incl. partial/pending):** `../SPEC/PROP_ORDERBOOK.md`
- **Hash-chained research ledger:** `../SPEC/dof_ledger.jsonl`

## Firms in this library (confirmed)

| File | Firm | Status for OUR strategy |
|---|---|---|
| `FundedNext_Stellar_2Step.md` | FundedNext (Stellar 2-Step) | ✅ **DEPLOY TARGET** — allows weekend holds, static DD, EA on MT5 |
| `GoatFundedTrader.md` | Goat Funded Trader | ⚠️ Historical — has **Goat Guard** (2% floating); dropped for FundedNext |
| `IXU_Capital.md` | IXU Capital | ❌ **Incompatible** — bans weekend holding, which is where our edge lives |

Partially researched (see `../SPEC/PROP_ORDERBOOK.md`): FTMO, FundingPips, E8 Markets, Legion Funding.

## What OUR strategy needs from a firm (fit checklist)
The CK_GOLD_COMBO edge is a **trend-follower that HOLDS trades over multiple days / weekends**
(the weekend-spanning trend trades are ~all of the profit — proven). So a firm must have:
1. **Weekend holding ALLOWED** ← the #1 dealbreaker (IXU fails this).
2. **STATIC** max-drawdown (our config is built for a fixed floor, not trailing).
3. **EA allowed on MT5, in BOTH challenge AND funded**, on accounts **< $50k**.
4. Daily loss **5% (or looser)**; if it counts floating and is measured on the initial balance, our
   0.02/0.03 sizing already respects it with a buffer.
5. Established firm with **proven payouts** (not just a cheap price).

## Universal rule-hunt checklist (vet ANY new firm with these — one unknown rule = a dead account)
1. Weekend / overnight holding allowed? (auto-close or breach?)
2. Drawdown: STATIC or TRAILING, and %? (does scaling later switch it to trailing?)
3. Daily loss: %, measured on INITIAL vs day-start, floating included?, reset time (server TZ)?
4. Max loss: %, floating included?, breach on touch (balance or equity)?
5. Floating-loss / equity guard (e.g. Goat Guard), incl. size thresholds?
6. A separate "risk limit" (e.g. FundedNext funded 3%, IXU funded 2%)? kill or profit-deduction?
7. Consistency / best-day rule (% of profit in one day) — payout gate? on-demand only?
8. Profit-concentration / single-trade-idea cap?
9. Minimum trading days (per phase AND per payout)? minimum hold time (quick-strike)?
10. Maximum time limit / inactivity breach?
11. News-trading rule (window, profit haircut), incl. funded stage?
12. Max lot / max total position / max risk per trade?
13. Max daily PROFIT cap (excess removed)?
14. Mandatory stop-loss?
15. Banned strategies (martingale, grid, HFT/tick-scalp, latency/arb) + thresholds?
16. Copy-trading / same-EA-across-accounts / identical-trades rule?
17. EA allowed in FUNDED? pre-approval? source-code proof? EA/VPS usage fee?
18. Platform (MT5 vs Match-Trader/cTrader) — is the EA allowed on it?
19. Profit split, payout cadence + method, first-payout caps, and PROVEN payout history?
20. Account sizes + fees + current discount code; fee refundable?

_Last updated: 2026-09-18._
