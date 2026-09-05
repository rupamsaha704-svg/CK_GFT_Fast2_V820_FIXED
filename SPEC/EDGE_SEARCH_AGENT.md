# Honest Continuous Edge-Search Agent — Build Spec

> Purpose: an autonomous agent that keeps generating NEW edge ideas, tests each on the MT5 Strategy
> Tester, validates them with a FIXED high bar (never lowered), keeps only what genuinely passes,
> combines survivors, and keeps going — until a robust edge is found, the user stops it, or the
> documented idea-space is honestly exhausted. It NEVER overfits and NEVER fabricates.
> Symbol: XAUUSD only. Lot respects the prop-firm $100 floating guard. Real money only after
> forward-demo proof + explicit human approval.

## 0. Inviolable rules (the whole point)
- **MT5 Strategy Tester (real ticks / Model 4) = the only trade simulator.** Python only reads MT5
  output; it never simulates trades.
- **The validation bar NEVER drops.** "Keep going until it passes" means keep trying NEW IDEAS at
  the same fixed bar — it does NOT mean loosen the criteria until a number appears. That would be
  fabrication and is forbidden.
- **"This idea has no robust edge" is a valid, logged result.** The agent may run through many ideas
  and find nothing that reaches the target — that is an honest possible outcome, not a failure to
  hide. No number is ever manufactured.
- Pin EVERY input on every run (Guard #20). Log every idea, trial, and verdict to the hash-chained
  ledger (`SPEC/dof_ledger.py`).
- Honest expectation, stated up front: **~100%/year on a $5,000 account under a $100 floating guard
  may be mathematically out of reach** (gap risk forces tiny lots). The agent's job is to find the
  BEST genuine edge and report truthfully what return the risk-box allows — not to force a target.

## 1. The gap/guard reality (bake into every sizing decision)
The $100 "Goat Guard" is a FLOATING (unrealized) loss limit. A stop-loss does NOT protect against
weekend/news GAPS — price can jump past the SL and float beyond $100 before exit. Proven on MT5:
0.01 lot worst ≈ −$53 (safe); 0.02 lot ≈ −$106 (BREACH). So worst-case loss ≈ (SL_distance + worst
historical gap) × lot × contract. **Every proposed lot must keep (worst historical gap × lot) below
the guard.** Do not propose a lot a normal gap would breach. This is why bigger lot ≠ more return
here; it is arithmetic, not a tuning choice.

## 2. The loop (one idea at a time)
1. **GENERATE** a NEW, structurally-motivated edge hypothesis from the source list (§3). Write it as
   a falsifiable statement with a PRE-DECLARED pass/fail threshold. Append to the ledger BEFORE any
   test (pre-registration).
2. **IMPLEMENT** it as a minimal, faithful MQL5 EA (XAUUSD, all inputs as pinned parameters,
   `OnTester` dumps `time,profit`). Compile; stop loudly on errors.
3. **SCREEN (fast, cheap):** quick "1 minute OHLC" backtest just to check it trades and isn't dead.
   Discard obviously dead/degenerate ideas here (cheap).
4. **VALIDATE (authoritative, real ticks Model 4):** IS vs OOS; current-regime primary window
   (last ~11 months) split into BOTH HALVES; walk-forward folds; cost/slippage stress; Monte-Carlo
   on the MT5 trade list; concentration (drop top-N winners).
5. **VERDICT (fixed bar — never lowered):** PASS only if ALL hold —
   - OOS PF ≥ 1.20 AND expectancy 95% CI lower-bound > 0;
   - BOTH current-regime halves PF > 1 (consistency);
   - no severe IS→OOS collapse (K3);
   - survives 1.5× cost/slippage stress;
   - edge NOT concentrated in a few trades (drop-top-10 stays positive);
   - adequate sample (OOS ≥ 200 trades) — else INSUFFICIENT (not a pass).
   Anything else = FAIL / REJECT / INSUFFICIENT, logged with reasons. Discard the idea, go to next.
6. **RISK/SIZING under the guard:** for a PASSing edge, compute the max lot whose worst-case
   (incl. worst historical gap) floating loss stays under $100, and the resulting annual return.
   Report it honestly (it may be modest).
7. **KEEP or DISCARD:** a PASSing edge enters the candidate pool AND the proof-gated knowledge ledger
   (`SPEC/knowledge_gate.py`, stored only with its passing-verdict hash). Failing ideas are discarded
   with a logged reason.
8. **COMBO:** once ≥2 candidates with LOW correlation exist, test combining them (diversification can
   raise return-per-drawdown → allow a larger lot within the guard). Validate the combo at the SAME
   bar. Only keep a combo that genuinely improves risk-adjusted return.
9. **NEXT IDEA:** loop. Keep going through new ideas.

## 3. Idea sources to mine (each is a HYPOTHESIS to FALSIFY, not a belief)
Session/time-of-day effects; volatility breakout (Donchian/ATR channels); mean-reversion (Bollinger/
RSI extremes); opening-range / gap plays; day-of-week & intraday seasonality; multi-timeframe
momentum; order-block / FVG / structure variants; XAU–XAG–DXY correlation & SMT filters; volatility-
regime switching; volume/tick-based proxies; combinations of the above. Reimplement TradingView /
literature indicators as testable rules — but NONE is assumed to work; each must earn its place at
the fixed bar.

## 4. Multiple-testing protection (CRITICAL — this is what keeps the search honest)
A search over many ideas WILL throw up lucky passes by chance (data-dredging). Guards:
- **Log the running trial count.** Treat a lone PASS among many trials with strong skepticism
  (apply Deflated-Sharpe / Bonferroni-style discounting; the more ideas tested, the higher the real
  bar for belief).
- **SEALED FINAL HOLDOUT:** reserve a block of data (e.g. the most recent unseen months) that is
  NEVER used during search. A candidate that passes §5 is unlocked against this holdout **exactly
  once**. Fail the holdout ⇒ discard, no second chances on that data.
- **FORWARD DEMO is the ultimate truth:** any candidate that survives holdout goes to a frozen
  forward demo before it is believed. History alone never certifies.
- No parameter tuning to maximize profit — only plateau/stability checks (a real edge is a plateau,
  not a lonely spike).

## 5. Autonomy & stopping
- Runs in Autopilot; does not ask for per-step approval; only STOPS before anything risking real
  money / a live account.
- Keeps looping through new ideas until: (a) a candidate passes §5 + holdout + is queued for forward
  demo, OR (b) the user says stop, OR (c) the documented idea-space (§3) is exhausted — in which case
  it reports honestly "no robust edge found in the searched space."
- Needs the PC on continuously (or a VPS) to run for long stretches; when the PC is off, nothing runs.

## 6. Output
- Per idea: a short Bengali report (idea, verdict, key metrics, why kept/discarded), all in the
  ledger. A living leaderboard of surviving candidates + any combo, with the honest max-return-under-
  guard for each. Never a fabricated or tuned-to-target number.
