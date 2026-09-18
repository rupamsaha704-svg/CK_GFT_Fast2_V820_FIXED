# CK_GOLD_COMBO — FundedNext Income & Scaling Plan (Bengali/English)

> ⚠️ **CORRECTED 2026-09-18 after FundedNext support confirmations.** The earlier "5k → 200k, same EA
> everywhere" ladder is **NOT viable** and has been fixed below. Three confirmed rules force the change:
> 1. **Accounts $50,000 and above are MANUAL-ONLY** — EAs are not allowed there. Our edge IS the EA, so
>    the automated plan is capped at **sub-$50k** accounts.
> 2. **"Identical trades across accounts are not allowed."** We cannot clone the same EA (same trades)
>    across many accounts. Multiple accounts would each need a genuinely DIFFERENT configuration.
> 3. **Funded accounts have a 3% RISK limit** ($150 on $5k) — max potential-SL + combined floating loss
>    at any time. Our funded config must be tightened to respect it, which LOWERS funded income below the
>    earlier ~$204/mo projection (exact number pending the funded rework + re-test).

## 0. What actually works (honest summary)
- The **EA runs only on accounts under $50,000** (with the $5 EA add-on).
- **One coherent account grown over time is the clean path** (no identical-trade risk).
- **Real income per $5k funded ≈ $154/mo take @80%** (real-ticks audit; below the old ~$204/mo Model-1 guess; the 3% rework may lower it a touch more). ৳30,000/mo needs ~a $10k account.
- The dream of "$8k–12k/mo from a $200k EA account" is **off the table** — $50k+ is manual-only.

## 1. Income by account size — HONEST real-ticks basis (take-home @ 80%)
> Base = the real-ticks audit of the $5k config: net $2,239.56 over ~11.6 months = ~$193/mo gross =
> **~$154/mo take @80%**. Everything scales linearly at the same safe ratio (0.004 lot / $1,000).
> EA works ONLY under $50k.

| Account | Safe lot | ~1 month take | ~6 months | ~12 months | Taka/mo (~৳115/$) |
|---|---|---|---|---|---|
| **$5,000**  | 0.02 | ~$154   | ~$925   | ~$1,850  | ~৳17,700 |
| **$10,000** | 0.04 | ~$309   | ~$1,850 | ~$3,700  | **~৳35,500** (crosses ৳30k) |
| **$15,000** | 0.06 | ~$463   | ~$2,780 | ~$5,560  | ~৳53,300 |
| **$25,000** | 0.10 | ~$772   | ~$4,630 | ~$9,260  | ~৳88,800 |
| **$40,000** | 0.16 | ~$1,236 | ~$7,410 | ~$14,820 | ~৳142,100 |
| ~~$50,000+~~ | — | **MANUAL ONLY (no EA)** | — | — | ❌ not our path |

⚠️ **These are AVERAGES of a LUMPY series** — 2 months made the whole $5k year and the recent 3 months were
negative; the same lumpiness scales up. Also: each bigger account must pass its OWN challenge (no income for
~2 months) + forward-demo; the 3% funded rework lowers funded income somewhat; and "identical trades across
accounts" is banned, so grow ONE account (FundedNext scale-up) or a few DIFFERENTIATED accounts — not clones.
*(Taka guide: $1 ≈ ৳110–120. ৳30,000/mo target is reached at about a $10k account.)*

## 2. Realistic growth path — grow from PAYOUTS, not your pocket

**Primary (cleanest) route — grow ONE account:**
- **Start ($5k):** pass the challenge (take the **VPS+EA add-on $10** since you run on your own AWS VPS;
  fee refunded on 1st payout) → run the safe config → bank every payout.
- **FundedNext scale-up plan:** for consistent performance, FundedNext grows your existing account's
  capital AND lifts the split 80% → 90% — **no new fee, no new account, no identical-trade issue.** This
  is the safest way to get to a bigger (still sub-$50k) EA account.

**Secondary route — a FEW differentiated sub-$50k accounts:**
- Only if each account runs a **genuinely different configuration** (so trades are NOT identical —
  required by the rule). This is more complex and must be **confirmed with support first**. Prefer the
  primary route unless support explicitly clears multi-account EA use for you.

**$50k+ / bigger money = manual trading only** — that is a different skill, not our validated EA edge.
We do NOT plan to chase it with the bot.

## 3. Iron risk-management rules (protect the whole ladder)
1. **Fixed safe lot ratio 0.004 lot per $1,000** (0.02 on $5k …) — never exceed it at any size.
2. **Funded accounts must also respect the 3% risk cap** (combined SL-risk + floating < 3% of initial):
   cap to one open position and/or a combined-floating flatten. This is enforced in the funded config.
3. **Every account keeps the full guard stack:** daily governor 4.5% of initial, static-halt 8%, news
   gate ON, `Combo_DailyRefInitial=true`, settlement-window block (`Combo_BlockEntryHours=0,1`).
4. **Buy the next account ONLY from banked payouts** — never money you can't afford to lose.
5. **Use the SCHEDULED payout** (not On-Demand) so the 40% consistency rule does not apply.
6. **Withdraw payouts regularly**; scale only the LOT with the account, never the risk %.
7. **Never run identical trades across accounts**; never deploy a size whose config isn't validated at
   that lot ratio.

## 4. Deployment configs (current)
- **Challenge:** `experiments/combo_fnext_03/CK_GOLD_COMBO_FundedNext.set` — FIX **0.02** + DTChop +
  settlement-block (0.02 NOT 0.03: the 5% daily includes floating; 0.03's ~$293 worst floating would
  breach, 0.02's ~$220 is safe).
- **Funded:** `experiments/combo_fnext_02f/...FUNDED.set` — FIX 0.02 base, **pending the 3%-risk rework**
  (cap combined risk < $150) before the account is funded.
- Journey (0.02): Step 1 (+8%) ~5–6 weeks, Step 2 (+5%) ~1.5–2 weeks, then funded. (A bit slower than the
  old 0.03 estimate, but breach-safe — a one-time hurdle, worth doing safely.)

_This is a projection/planning tool. Real capital is committed only after the forward-demo passes and
matches the backtest, AND a human approves._
