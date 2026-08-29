# SESSION EXPORT — Backtest Degradation Diagnostic + Code Review (XAUUSD buy-only knee EA)

> Honest, exhaustive export of ONE Kiro session. Nothing here is fabricated.
> Language of original discussion: Bengali (user) + English (technical review that the user pasted).
> **Important honesty note:** In THIS session **no new code file, script, or config was created by the
> agent.** The session consisted of (a) a technical code-review text that the *user pasted in*,
> (b) two photos (phone pictures) of the MT5 Strategy Tester, and (c) the agent's written analysis of
> why the backtest result degrades. All numbers below were read off **low-quality phone photos of a
> screen**; digits that are uncertain are explicitly flagged. Re-verify against the authoritative
> `ReportTester-*.html` files already in this repo before trusting any single figure.

---

## 0. HOW THIS SESSION RELATES TO THE REST OF THE REPO

This is a **diagnostic addendum** to the main GFT gold-EA work already captured in
`docs/session_exports/SESSION_gft_gold_ea_risk_mgmt.md`. Same project family: the **CK_GFT knee-breakout
Expert Advisor** for **XAUUSD M5**, whose goal is to pass a **Goat Funded Trader (GFT) $5,000 2-step
challenge**. The code fragments the user pasted here (`g_dir`, `g_trigger`, `TryArmSetup()`,
`OpenTrade()`, `LotForRisk()`, `InpRR`, `InpMaxSpreadPoints`) match the CK_GFT_Fast* EA family in this
repo. The MT5 Navigator in the screenshot shows the user's EA library (CK_GFT_Fast, CK_GFT_Fast2,
CK_Falcon_Gold, CK_Gladiator_Gold, CK_ICT_SmartMoney_Pro, CK_NightGuard_Gold, CK_Phoenix_Gold,
CK_Power3_Gold, CK_ProEdge_Gold, CK_RSI_Bounce, CK_ShortKing_Gold V1/V2/V3, CK_Titan_Gold, and
`ExpertMAPSARSizeOptimized`). The tested EA in both screenshots is **BUY-ONLY** (0 short trades).

---

## 1. PURPOSE OF THIS SESSION

The user was worried (in Bengali): the EA looks good **before** running the full backtest, but **after
the backtest the result collapses to almost break-even** (near "loss-equivalent"). They fear they cannot
pass the GFT account this way and asked the agent to look at *why the result drops so much*.

Concretely the user provided:
1. A long **English technical review** of the EA (pasted as text — see §3). It lists bugs and
   strategy-level suggestions for a buy-only XAUUSD EA.
2. **Two MT5 Strategy Tester result photos** (see §4) — one "good" run and one near break-even run.

The agent's job was to **explain the degradation** and recommend fixes. No code was written or committed
in this session.

---

## 2. KEY DECISIONS / CONCLUSIONS REACHED

The agent's diagnosis (agreed reasoning, not a fabricated test result):

1. **Root cause = overfitting + regime dependency.** One period shows Profit Factor ~2.0+, another
   period shows PF ~1.06 (essentially noise/break-even). A strategy tuned on one slice of XAUUSD data
   stops working when the market regime changes. This is the classic symptom the user is seeing.
2. **The EA is BUY-ONLY.** Both screenshots show **Short Trades = 0 (0.00%)**. With no sell side, when
   gold enters a downtrend or chop the EA keeps buying weak pullbacks and the win rate falls
   (~37.76% → ~25.84% between the two runs).
3. **Win rate is low (25–38%).** At that hit-rate the system needs a high realized RR (≈3:1) to be
   net-positive; consecutive losses reach ~9, so it is fragile.
4. **A near-break-even PF (~1.06) over ~80–90 trades is not statistically trustworthy.** Do not treat it
   as a real edge; need out-of-sample / walk-forward and several hundred trades.
5. **Do NOT raise risk to "fix" performance** — with unstable PF, higher risk just accelerates drawdown.
6. The pasted code review's **priority fixes** were endorsed: confirm breakout on **Bid** (not Ask),
   compute **TP from the actual fill price** (not from the trigger), **skip trades when computed lot < min**,
   and **check the trade-execution result** (`OrderSend` return / `retcode`).

**No new backtest was executed by the agent in this session.** The comparison is between the user's own
two screenshots.

---

## 3. CODE & FILES — THE TECHNICAL REVIEW THE USER PASTED (verbatim intent, corruption flagged)

> This review was **pasted by the user** (likely produced by another tool/session). It is preserved here
> because it may be the only copy. The user's paste was **partly corrupted** — several code lines came
> through garbled (e.g. `if(lots  1e-8)`, `if(riskMoney = minDist ...`, `if(dir  InpMaxSpreadPoints)`).
> These are reproduced faithfully with a `⚠CORRUPTED` marker; a future agent must reconstruct the intended
> logic from context, NOT assume the fragment compiles.

### 3.1 Problems the review identified

**(1) It is buy-only.** Logic only opens buys:
```mql5
if(g_dir > 0 && ask >= g_trigger){ OpenTrade(+1); Disarm(); }
```
So when XAUUSD changes regime, the EA has no sell-side edge and keeps buying weak pullbacks.

**(2) Buy trigger uses Ask against a candle high.** The candle high is based on Bid/chart price, but entry
compares `ask >= g_trigger`. Because `Ask = Bid + spread`, this can enter *before* the visible breakout.
Recommended: confirm with Bid, then buy at Ask:
```mql5
if(tick.bid >= g_trigger)   // confirm breakout on Bid
   // ... then open BUY at Ask
```

**(3) TP is computed from the trigger, but real risk is from the Ask/fill.** `TryArmSetup()` computes TP
from `g_trigger`, while `OpenTrade()` actually fills at Ask. With wide spread/slippage the real RR is worse
than intended. Recommended:
```mql5
double entry = tick.ask;
double oneR  = entry - sl;
double tp    = entry + InpRR * oneR;
```

**(4) Lot sizing can over-risk / is unsafe.** The pasted `LotForRisk()` and digits helper came through
**corrupted**; reproduced as received:
```mql5
// ⚠CORRUPTED as pasted — do not assume this compiles; reconstruct intent.
... if(lots  1e-8)   // (comparison operator lost in paste)
   {
      s *= 10.0;
      d++;
   }
   return d;
}

double LotForRisk(double riskMoney, double entry, double sl, ENUM_ORDER_TYPE type)
{
   if(riskMoney ...    // (body lost in paste)
```
Intended behaviour (from context): size the lot from a fixed risk-money amount and the SL distance, then
**if the computed lot is below the broker minimum, SKIP the trade** rather than silently flooring it up to
a bigger-than-intended risk.

**(5) minDist / TP-SL distance validation** (pasted, partly corrupted):
```mql5
// ⚠CORRUPTED as pasted
   ... >= minDist && tp - entry >= minDist);
   else
      return (sl - entry >= minDist && entry - tp >= minDist);
}
```
Intent: verify both SL and TP are at least the broker's minimum stop distance from entry (buy vs sell
branches).

**(6) OpenTrade / spread guard** (pasted, partly corrupted):
```mql5
// ⚠CORRUPTED as pasted
bool OpenTrade(int dir)
{
   if(dir  InpMaxSpreadPoints)   // (spread check condition lost in paste)
      return;
   if(!TradingAllowed())
      return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;
   // Use Bid to confirm chart breakout.
   if(g_dir > 0 && tick.bid >= g_trigger)
   {
      OpenTrade(+1);
      Disarm();
   }
}
```
Intent: block entries when spread > `InpMaxSpreadPoints`, bail if trading not allowed or tick unavailable,
and confirm the breakout on Bid. (Note the fragment appears to mix the arm/trigger loop into `OpenTrade`;
the real EA separates arming from execution — reconstruct carefully.)

### 3.2 Strategy-level suggestions from the review (endorsed by the agent)

1. **Add sell logic** — mirror the buy setup; XAUUSD M5 needs a sell side or a stronger HTF trend filter.
2. **Higher-timeframe filter** — e.g. only buy when M15/H1 price is above EMA 100/200 with positive slope.
3. **Session filter** — avoid rollover / low-liquidity hours; gold spread & slippage destroy M5 systems.
4. **Invalidate stale setups** — if price breaks below the knee low before triggering, disarm.
5. **Do not trust 80–100 trades** — PF ~1.06 is basically noise; require OOS, walk-forward, several hundred
   trades before believing it.
6. **Do not increase risk to fix performance** — unstable PF + higher risk = faster drawdown.

**Biggest immediate fixes (review's own summary):** use Bid for breakout confirmation, compute TP from the
actual entry, skip trades when lot < minimum, and check the trade execution result.

---

## 4. DATA — THE TWO MT5 STRATEGY-TESTER SCREENSHOTS

> ⚠ ALL values below were transcribed from **blurry phone photos of a monitor**. Treat every number as
> approximate. Where the reading is doubtful it is marked `(uncertain)`. **Both runs are BUY-ONLY**
> (Short Trades = 0), which is the single most reliable fact from the images. The authoritative source is
> the repo's `ReportTester-*.html` / `report 17` files — reconcile against those.

**Common to both:** Symbol XAUUSD, Timeframe M5, Account = MetaQuotes-Demo (Hedge), Initial Deposit
$5,000.00, History Quality 100%.

### Screenshot 1 — the "GOOD" run
| Metric | Value | Note |
|---|---|---|
| Total Net Profit | **$3,894.96** | fairly clear |
| Gross Profit | ~$6,269.32 | uncertain digits |
| Gross Loss | ~$2,374–2,817 | uncertain (Net implies ≈ −$2,375) |
| Profit Factor | **~2.04–2.34** | ⚠ agent's chat said **2.04**; photo text looked like **2.34** — RECONCILE |
| Recovery Factor | ~3.05 | uncertain |
| Expected Payoff | ~39.32 | uncertain |
| Sharpe Ratio | ~28.37 | uncertain (implausibly high → likely mis-read) |
| Balance Drawdown Maximal | ~$905.78 (10.42%) | uncertain |
| Balance Drawdown Relative | ~10.42% ($903.76) | uncertain |
| Equity Drawdown Maximal | ~$1,139.60 (12.89%) | uncertain |
| Total Trades | **98** | clear |
| Total Deals | 196 | |
| Short Trades (won %) | **0 (0.00%)** | ✅ confirms BUY-ONLY |
| Long Trades (won %) | **98 long, 37.76% won** | clear-ish |
| Loss Trades (% of total) | ~61 (62.24%) | → ~37 profit trades |
| Largest profit / loss trade | ~ +$642.48 / −$207.20 | uncertain |
| Average profit / loss trade | ~ +$170.22 / −$46.19 | uncertain |
| Max consecutive losses | ~9 (−$774.94) | uncertain |
| Margin Level | ~429% | uncertain |

### Screenshot 2 — the near-BREAK-EVEN run
| Metric | Value | Note |
|---|---|---|
| Total Net Profit | **$133.52** | fairly clear |
| Gross Profit | ~$2,545.12 | uncertain |
| Gross Loss | ~$2,411.60 | uncertain |
| Profit Factor | **1.06** | clear |
| Recovery Factor | ~0.34 | uncertain |
| Expected Payoff | ~1.50 | uncertain |
| Sharpe Ratio | ~1.50 | uncertain |
| AHPR | 1.0004 (0.04%) | |
| GHPR | 1.0003 (0.03%) | |
| Balance Drawdown Absolute | ~$356.16 | uncertain |
| Balance Drawdown Maximal | ~$385.20 (7.19%) | uncertain |
| Equity Drawdown Maximal | ~$394.32 (7.36%) | uncertain |
| Equity Drawdown Relative | ~7.84% ($391.92) | uncertain |
| Z-Score | ~0.67 (49.71%) | uncertain |
| Total Trades | **89** | clear |
| Total Deals | 178 | |
| Short Trades (won %) | **0 (0.00%)** | ✅ confirms BUY-ONLY |
| Long Trades (won %) | **89 long, 25.84% won** | clear-ish |
| Loss Trades (% of total) | ~66 (74.16%) | → ~23 profit trades (25.84%) |
| Largest profit / loss trade | ~ +$320.40 / −$169.04 | uncertain |
| Average profit / loss trade | ~ +$101.96 / −$33.51 | uncertain |
| Max consecutive wins | ~2 (+$445.76) | uncertain |
| Max consecutive losses | ~9 (−$754.88) | uncertain |
| Margin Level | ~370.46% | uncertain |

### The degradation story (side-by-side)
| Metric | Run 1 (good) | Run 2 (near BE) |
|---|---|---|
| Total Net Profit | $3,894.96 | $133.52 |
| Profit Factor | ~2.04–2.34 | 1.06 |
| Total Trades | 98 | 89 |
| Long win % | 37.76% | 25.84% |
| Short trades | 0 | 0 |

The win rate fell from ~38% to ~26% and PF collapsed from ~2 to ~1.06 across the two periods — consistent
with **regime-dependent, buy-only, overfit** behaviour. (The two screenshots are almost certainly two
different date ranges of the same EA; the exact date ranges were **not** legible in the photos — a future
agent should confirm them from the MT5 report headers.)

---

## 5. STRATEGY RULES (as referenced this session)

The tested EA is the **buy-only knee-breakout** on **XAUUSD M5** (see the full, canonical rules in
`SESSION_gft_gold_ea_risk_mgmt.md` §2). Relevant to this session:
- **Direction:** BUY only in the tested build (0 short trades in both reports). The main-session code
  *does* have a mirror SELL side (added in v17), so the tested build here was either an older/ buy-only
  variant or had sell disabled.
- **Entry:** break above the red "knee" candle high (`g_trigger`); trend filter via EMA fast/slow.
- **SL:** knee low − ATR×buffer. **TP:** trigger + `InpRR` × (trigger − SL). `InpRR` referenced ≈ 3.0.
- **Spread guard:** `InpMaxSpreadPoints` (review suggests tightening, e.g. 30 → 20).
- The review's proposed rule changes (Bid-confirm entry, TP-from-fill, skip-if-lot<min, check exec result,
  add sell, HTF filter, session filter, invalidate stale setups) are **suggestions — NOT yet implemented**.

---

## 6. USER INSTRUCTIONS / PREFERENCES (from this session)

- **Respond in Bengali.** (The user writes in Bengali; the agent replied in Bengali.)
- **Overarching goal:** pass the **Goat Funded Trader (GFT) $5,000** challenge; the user is anxious about
  the strategy not being stable enough to pass.
- **Capital preservation matters** — the user is stressed ("চিন্তায় পড়ে গেছি") about the result being weak.
- (From the broader project, carried in the main export) capital preservation > profit; strict money
  management; no martingale; respect GFT drawdown rules.

---

## 7. UNFINISHED WORK / NEXT STEPS

Nothing was implemented in this session. Concrete next steps the agent recommended:
1. **Add / enable SELL logic** (mirror of the buy setup) and re-test.
2. **Add a higher-timeframe trend filter** (M15/H1 EMA 100/200 + slope) so buys only fire in uptrends.
3. **Add a session filter** for XAUUSD (favour London 08:00–12:00 and NY 13:00–17:00 UTC; avoid Asian
   chop and rollover). — Exact hours to be validated, not a proven optimum.
4. **Apply the code fixes:** Bid-confirmed breakout, TP from actual fill, skip when lot < broker min,
   and check `OrderSend`/retcode.
5. **Tighten spread guard** (e.g. `InpMaxSpreadPoints` 30 → 20).
6. **Validate properly:** MT5 Walk-Forward (≈70% in-sample / 30% out-of-sample), multiple periods, aim for
   several hundred trades before trusting PF.
7. **Reconcile the screenshot numbers** against the repo's `ReportTester-*.html` and `report 17` files
   (especially the ambiguous Profit Factor 2.04 vs 2.34 and the two date ranges).

**Open questions:** What exact EA build produced the two screenshots (which CK_* file / which inputs)?
What were the two date ranges? Was the sell side disabled or is this a genuinely buy-only variant? These
were not resolvable from the photos.

---

## 8. WARNINGS FOR A FUTURE AGENT

1. **All screenshot numbers are OCR/eyeball reads from blurry phone photos — treat as approximate.** In
   particular the agent's chat table stated **Profit Factor 2.04** for Run 1, while the photo text looked
   more like **2.34**. This discrepancy is UNRESOLVED — reconcile against the HTML reports.
2. **The pasted code fragments are CORRUPTED** (lost comparison operators, truncated function bodies). Do
   NOT copy them verbatim into an EA; reconstruct intent from §3 and the canonical EA files in the repo.
3. **The tested EA is buy-only** — that is the single most robust finding, and the most likely structural
   cause of regime-dependent collapse.
4. **PF ~1.06 over ~89 trades is statistically meaningless** as evidence of edge; do not "confirm" the
   strategy on it, and do not raise risk to compensate.
5. **No new backtest, code, or file was produced by the agent in this session** — so there is no verified
   result to cite from here beyond the two user screenshots. Anything presented as a "result" from this
   session is either the user's screenshot or a qualitative diagnosis, never an agent-run test.
6. Sharpe ~28 in Run 1 is almost certainly a mis-read of the photo; ignore it unless the HTML confirms it.

---

*End of export. This is a truthful record of a short diagnostic/review session; where the session
produced no artifact, that is stated plainly rather than filled with invented detail.*
