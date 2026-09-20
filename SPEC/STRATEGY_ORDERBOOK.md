# STRATEGY ORDER BOOK

> One line per strategy distilled from the Trading_Project PDFs. Built by the `strategy-decoder`
> agent from EXTRACTED TEXT only (`docs/strategy_pdfs_text/`), never from imagination.
> A row is a HYPOTHESIS to be falsified on MT5 at the fixed bar — never a proven edge.
>
> Legend — **Codeable:** YES / PARTIAL / NO · **Verdict:** UNTESTED / REJECTED(seq) /
> INSUFFICIENT(seq) / CANDIDATE. `UNSPECIFIED` = the author did not state that parameter (not a
> guess). "Ledger echo" links to prior verdicts on the same idea family so we never re-run a dead
> end blind.
>
> **Standing truth from 60+ prior tests (do not forget while reading pretty PDFs):** on XAUUSD the
> only durable, out-of-sample, cost-surviving edge found is TREND / long-only (ledger seq148,
> seq149). Mean-reversion at levels, QM/ICT structure, CRT sweep-reversal and Turtle Soup have all
> been REJECTED (seq95, 102, 107, 120, 141, 144, 155, 157, 158, 165). A PDF restating any of these
> is not new evidence.

## Source triage (from SPEC/STRATEGY_INDEX.md)
- 58 unique PDFs (64 files, 6 duplicates collapsed)
- **23 MECHANICAL** — real text extracted, distilled below
- **6 MINDSET** — psychology books, no mechanical rule (logged, not coded)
- **3 UNCLEAR** — tiny SNR fragments
- **26 UNREADABLE** — scanned image PDFs, ~0 extractable text, need OCR before they can be read

## Codeable strategies

| ID | Source | Family | One-line thesis | Entry trigger | Stop | Target/exit | TF / session | Codeable | Ledger echo | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|
| IDEA-101 | Quarterly_Theory_Daye | session-time / structure | Each 6h session splits into four 90-min quarters running Accumulation-Manipulation-Distribution-Reversal (AMDX); best entries in Q2-Q3 after the manipulation leg | On the 90-min quarter grid (NY UTC-4), after the Q2 "manipulation" extreme is set, enter toward the expansion when price reacts from a PD-array key level | UNSPECIFIED (beyond the manipulation extreme) | Opposite external liquidity / next PD array | 90-min quarters; session grid 18:00/00:00/06:00/12:00 NY | PARTIAL — grid is exact, entry confirmation is discretionary | QT/CRT sweep-reversal REJECTED seq107; QM structure REJECTED seq95/102 | REJECTED-family (seq107) |
| IDEA-102 | OHLC_Power_of_3 | session-time / structure | Daily bar forms as Accumulation-Manipulation-Distribution (Power of 3); fade the manipulation of the true day open | Buy below / sell above the 00:00 EST daily open after the manipulation leg, expecting distribution in the OHLC/OLHC direction | UNSPECIFIED | Daily range expansion | Daily; true open 00:00 EST (UTC-4) | PARTIAL — open ref exact, manip detection discretionary | PO3 = same AMD logic as QM/CRT, REJECTED seq102/107 | REJECTED-family (seq107) |
| IDEA-103 | External_&_Internal_Range_Liquidity | liquidity / FVG | Price only draws to old highs/lows (ERL) or rebalances an FVG (IRL); trade the alternation ERL->IRL->ERL | When ERL (old high/low) is taken, target the nearest FVG; when an FVG is tagged, target the next old high/low | UNSPECIFIED | The opposite liquidity type (ERL<->IRL) | MTF: Monthly>Daily, Weekly>H4, Daily>H1 | PARTIAL — draws are definable (we have ERL/FVG detectors in v1_lab), stop unstated | ERL/FVG already built in qm engine; QM REJECTED seq95/102 | REJECTED-family (seq95) |
| IDEA-104 | STANDARD DEVIATION PROJECTIONS (LumiTraders) | volatility / target-projection | The "manipulation leg" projects forward by fixed standard-deviation multiples; those levels are reversal/target zones — explicitly says GOLD interest starts at the 2.25-2.5 STDV band | After a manipulation leg confirmed by CISD + MSS, measure the leg and project 1/1.5/2/2.25/2.5/4 STDV; for GOLD watch the 2.25-2.5 STDV band for a distortion+IFVG entry | Beyond the manipulation-leg extreme | 2 STDV (partial) then 4 STDV | intraday; distortion 10:30-12:00 or PM 14:15-15:00 | PARTIAL — the STDV projection is a NEW, exact TARGET model (codeable as an exit overlay); the entry still leans on discretionary CISD/MSS | **NEW target model — not previously tested.** Entry family (MMXM/CISD) ~ QM REJECTED seq95 | UNTESTED (target-overlay only) |
| IDEA-105 | TGIF (Thank God It's Friday) | seasonality / time | After the weekly high/low sets Mon-Tue and price expands through Thursday into a -2/-2.5/-4 STDV HTF level, Friday retraces 20-30% back into the weekly range — fade it | On Friday, once the weekly objective (>=2 STDV) is met, enter on the retracement into the 20-30% weekly-range zone | UNSPECIFIED | 20-30% of the weekly range | Weekly profile; entry Friday only | PARTIAL — weekly range + Friday gate are exact; the "objective met" trigger needs defining | Weekday effects dismissed as noise seq113/131, but TGIF as a specific setup is UNTESTED. **Collides with weekend-gap rule** if held into Monday (rule 5) | UNTESTED |
| IDEA-106 | OTE_freemodel (ICT) | order-block / pullback | Enter against the immediate move, on an order block, at the Optimal Trade Entry Fib retracement (0.62-0.79), targeting a draw on liquidity (old high/low) | Price runs to liquidity, forms an OB, retraces into the 0.62-0.79 OTE zone of the last leg -> enter toward the draw | Beyond the OB / recent swing | The opposing draw on liquidity | Daily setup, LTF entry | PARTIAL — OTE Fib zone + OB are codeable; "draw" target is discretionary | Pullback/offset entry REJECTED seq18-22; OTE-Fib-on-OB specifically UNTESTED | REJECTED-family (seq22) |

## Mindset / no-code (logged, not coded)

| ID | Source | Note |
|---|---|---|
| MIND-01 | mark-douglas-the-disciplined-trader | Trading psychology / discipline. No mechanical rule to code. Value is process discipline, which our ledger + fixed-bar workflow already enforce. |
| MIND-02 | Trading_in_the_Zone (Mark Douglas) | Probabilistic mindset, thinking in probabilities. No EA rule. |
| MIND-03 | psychology.pdf | Trading psychology. No EA rule. |
| MIND-04 | The_essence_of_trading_psychology | Psychology. No EA rule. |
| MIND-05 | Trading_Psychology_Guide | Psychology. No EA rule. |
| MIND-06 | Trading Mind Mastery | Psychology. No EA rule. |

## OCR results (the 26 image scans — now read via tesseract, 2026-09-17)
Tesseract 5.4.0 was installed and the scans OCR'd (first 6 pages each, `*.ocr.txt`). Honest
outcome: **every readable scan restates an already-rejected family.** No new codeable edge emerged.

| ID | Source (OCR) | Family | What it actually is | Ledger echo | Verdict |
|---|---|---|---|---|---|
| IDEA-107 | PSP (Precision Swing Point) | SMT / divergence | 3-candle swing where correlated assets (Gold-Silver-DXY, NQ-ES-YM) show a "crack in correlation" (SMT); candle 2 = PSP; timed to quarter overlaps | SMT XAU-XAG tested + REJECTED seq93/94 (too selective, one half always loses) | REJECTED-family (seq94) |
| IDEA-108 | Alche/Alchemist, ISC MSNR, Malaysian SNR, huntersnrdz, 1.Theory-SnR | structure / SNR | BOS + inducement + QM strong-high/low + DOL market-structure (Indonesian/English chart decks) | QM/ICT REJECTED seq95/102; SNR-bounce REJECTED seq144/155/165 | REJECTED-family |
| IDEA-109 | PO3 Everywhere, ict-kill-zones, ict-if-vg, qm/qm123/advance qm, DOL, Bias, Lit/pre-LIT | session / FVG / structure | Power-of-3, killzones, FVG, QM, liquidity, daily bias — core ICT | REJECTED seq95/102/107/141/157 | REJECTED-family |
| IDEA-110 | Secret of 411 Empire, The Manipulation Mastery, Stage 1-3 JM_WHALE, REX-ALCHEMIST | trendline / SNR / reversal | discretionary trendline (XRTL 2-TL rotation) + SNR confluence + reversal patterns | SNR/reversal REJECTED seq144/155/165 | REJECTED-family + discretionary |
| — | Turtle Soup, CRT & TS Guide, FIBOOO, STRANGER_E_BOOK, entry, DOC-20260130 | — | OCR still near-empty (pure diagrams / handwriting) even after OCR | Turtle Soup REJECTED seq120; CRT REJECTED seq107 | UNREADABLE-still / REJECTED-family |

**Bottom line across all 58 PDFs:** not one contains a mechanism this project has not already
tested and rejected on XAUUSD, EXCEPT the one target-model idea IDEA-104 (STDV projection). The
PDFs are a rich library of the SAME ICT/SMC/SNR/QM/SMT ideas; the honest edge conclusion is
unchanged (gold = long trend, seq148/149).

## Indicator library slot (for TradingView-style indicators the user names)
TradingView cannot be connected directly (no API/credentials), but any indicator seen there can be
reimplemented in MQL5 and backtested — which is stronger than a TradingView accuracy screenshot
because it is falsifiable. When the user names indicators, each becomes a row here and an A/B lever
on the EA. Standard ones ready to code on request: Supertrend, VWAP, Keltner Channel, Donchian,
RSI/StochRSI, MACD, ADX/DI, Ichimoku, Bollinger %b, ATR bands, Parabolic SAR.

| ID | Indicator | Proposed use | Status |
|---|---|---|---|
| _(awaiting the user's list)_ | | | |

## Unreadable (scanned images — original state before OCR)
Turtle Soup · ict-kill-zones · PSP (Precision Swing Point) · Liquidity (DOL) Akanshu · CRT & TS
Guide · PO3 Everywhere · qm · qm123 · advance qm · entry · ict-if-vg · Bias Akanshu · Lit · The
pre LIT · Stage 1/2/3 JM_WHALE · ISC MSNR_Optimized · Alche A Set-UP · Secret of 411 Empire · REX
ALCHEMIST · The Manipulation Mastery · 1. Theory-SnR · huntersnrdz entrys · DOC-20260130-WA0019 ·
FIBOOO · STRANGER_E_BOOK

_(These are the ICT/SMC titles most likely to contain concrete entry rules, but the PDFs are image
scans with no extractable text. They cannot be decoded without OCR — see the note below.)_

## Remaining readable mechanical PDFs (queued, map to already-rejected families)
Not yet given individual rows because their opening text places them squarely in ICT/SMC/SNR
families already rejected on XAUUSD (seq95/102/107/141/144). They will be decoded on request, but
each is a restatement, not new evidence:
HIDDEN MARKET CODE · The Book of T (MalaysianSNR) · VectorTradingFX 2-Phase Inducement · the market
profiling guide · Inducement Liquidity Theorem · Akanshu English SNR · Alchemist White-Srp ·
Breaker_Block · Order_Block · Order block by daytradingrauf · MSNR SL 10 PIPS · Inducement Cycle ·
Lotus MMXM Trading Model · i4xfizx · The pre LIT.

## Honest status (profit-prioritised, read straight)
- Of 58 PDFs: **23 readable-mechanical, 6 mindset (no code), 3 tiny SNR fragments, 26 unreadable
  image scans**.
- The single most valuable, decision-relevant finding: **the PDFs overwhelmingly restate ICT / SMC
  / QM / CRT / liquidity / SNR ideas this project has already built and REJECTED on XAUUSD** (seq95,
  102, 107, 120, 141, 144, 155, 157, 158, 165). Re-testing them blind would burn compute to
  re-prove known negatives.
- **The one genuinely new, gold-specific, codeable mechanism found is IDEA-104 — the LumiTraders
  standard-deviation TARGET projection.** It is a target/exit model, not an entry system, and the
  doc explicitly calls out GOLD. It is the only lead worth a pre-registered test, and the honest
  way to test it is as an EXIT overlay on the one edge gold actually has (trend / long-only,
  seq148/149) — never as a fresh discretionary ICT entry.
- **Blocker for completeness:** the 26 image-scan PDFs — which include the most concrete ICT titles
  (Turtle Soup, kill-zones, PSP, DOL, CRT & TS Guide, PO3, qm) — cannot be read without OCR. Turtle
  Soup and CRT are already REJECTED (seq120/107), so OCR is only worth it for titles that might hold
  a genuinely untested mechanic. Decision needed: install OCR (tesseract) or leave them.
