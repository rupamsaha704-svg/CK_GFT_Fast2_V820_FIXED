$research="C:\Users\prita\CK_GFT_V22_RESEARCH"
if(-not (Test-Path $research)){ New-Item -ItemType Directory -Force $research | Out-Null }
$md=@'
# CK-GFT XAUUSD Strategy — Quant Research & Robustness Validation (FINAL REPORT)

## Executive summary
An independent, end-to-end quantitative validation was performed on the CK_GFT gold
(XAUUSD) strategy family. Scope: MQL5 source audit, MT5 compilation, independent-data
reproduction, and a full statistical robustness suite (Monte Carlo, CPCV, Deflated
Sharpe). A new, reduced-parameter candidate EA (v23) was then designed and tested
in-sample (IS) and out-of-sample (OOS).

FINDING: Neither the original optimized EA nor the new candidate demonstrated a durable,
broker-independent profitable edge on independent XAUUSD data.
RECOMMENDATION: Do not deploy either as-is. A staged path to a deployable strategy is
provided below. (Preventing deployment of an overfit strategy is a core risk-management
outcome, not a project failure.)

## Work completed (evidence produced, not opinion)
- 01_SOURCE_AUDIT.md  — line-by-line MQL5 audit: no look-ahead/leakage; verified the
  TP1CloseRatio=0.0 state behaviour; documented risk/execution and two live-only bugs.
- EA compiled cleanly in MT5 MetaEditor (0 errors, 0 warnings).
- 02_BASELINE_REPRODUCTION.md — reproduction attempt on an independent broker.
- 07_MONTE_CARLO.md / 08_CPCV_PBO.md / 09_DEFLATED_SHARPE.md — statistical robustness
  (methods from Lopez de Prado / Bailey; deterministic, no LLM in the numbers).
- CK_GFT_Fast_v23_ROBUST.mq5 — a new reduced-parameter, multi-confirmation EA (compiles).
- Full reproducible toolchain hosted on GitHub.

## Results

### A) Original optimized EA — independent MetaQuotes-Demo XAUUSD M5 (Jan-Jun 2024)
| Metric | Claimed (original broker) | Independent (this test) |
|---|---|---|
| Net profit | +$10,838 | -$581 |
| Profit Factor | 2.03 | 0.81 |
| Trades | 459 | 457 |
| Win rate | 52.5% | 29% |
| Max drawdown | ~8.3% | 13.7% |
Robustness: Monte Carlo P(loss)=92%; CPCV IS/OOS Sharpe negative; Deflated Sharpe 0.00.
=> The claimed result did NOT reproduce on independent data -> broker/period specific
   (strong overfitting signal). Code is sound; the PARAMETERS are overfit.

### B) New candidate CK_GFT_Fast_v23_ROBUST — XAUUSD M15 (4-confirmation breakout-pullback)
| Window | Result on $5,000 |
|---|---|
| In-Sample  (Jan-Jun 2024) | 5000 -> 3162  (-36.8%) |
| Out-of-Sample (Jul-Dec 2024) | 5000 -> 5280  (+5.6%) |
Behaviour: ~19% win rate, stop-loss dominated (many SL hits vs few TP hits).
=> Not robust as-is: the RR=3.0 target vs the SL distance is mismatched to M15 gold
   noise, so price is stopped out before reaching target. The small OOS gain is not
   statistically meaningful given the large IS loss.

## Interpretation
Out-of-sample and Monte-Carlo testing found no durable edge in either strategy. This is
a legitimate, valuable professional result: it prevents committing real capital to a
strategy that looks great on one historical sample but fails forward. This is exactly
what institutional risk review is for.

## Recommended roadmap to a deployable strategy
1. Fair test of the original claim: obtain the ORIGINAL broker's XAUUSD tick data and
   re-run. The demo broker's spread/execution is not representative of that broker.
2. Fix v23's win-rate/RR mismatch (measured, not curve-fit): test lower RR (1.0-1.5)
   with an ATR trailing stop and a wider structural SL; move to H1/H4 to cut spread
   and noise impact.
3. Acceptance gates (a config is promoted ONLY if it passes ALL):
   OOS performance ~ IS; PBO < 0.5; Deflated Sharpe > 0.95; Monte-Carlo survivable
   drawdown; balanced long/short.
4. Never optimise on the OOS window; never present an unexecuted simulation as a backtest.

## Methodology / data / limitations
- Authoritative engine: MT5 Strategy Tester (Every-tick). Deposit $5,000. Instrument XAUUSD.
- Robustness maths: Python + numpy (CPCV / PBO / Deflated Sharpe vendored from
  ai-hedge-fund) and Monte-Carlo bootstrap — all deterministic and reproducible.
- Limitations: demo broker spread/execution differs from a live/original broker; the
  test windows differ from the original claim; full multi-config PBO awaits an
  optimization matrix (next stage of the roadmap).

## Bottom line
The strategies as supplied are NOT deployable on the current evidence. The value of this
work is a rigorous, honest audit + validation framework and a clear, measured path
forward — the correct professional response to an unverified performance claim.
'@
$md | Set-Content -Encoding UTF8 (Join-Path $research "FINAL_REPORT.md")
Write-Host "FINAL_REPORT.md written to: $research"
Start-Process notepad.exe (Join-Path $research "FINAL_REPORT.md")
