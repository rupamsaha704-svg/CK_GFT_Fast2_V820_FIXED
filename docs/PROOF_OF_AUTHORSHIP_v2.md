# CK_GOLD_COMBO_v2 Expert Advisor
## Proof of Authorship and Complete Development Documentation

| | |
|---|---|
| **EA name** | CK_GOLD_COMBO_v2 (`CK_GOLD_COMBO_v2.mq5`) |
| **Version** | 2.00 |
| **Symbol** | XAUUSD only |
| **Platform** | MetaTrader 5 (MT5) |
| **Target broker** | FundedNext (Stellar 2-Step $6,000, MT5) |
| **Document date** | 2026-09-22 |
| **Author** | account holder (I, the trader) |
| **Source repository** | Local workspace `C:\Users\prita\CK_GFT_Repo` |

---

## 1. Statement of Authorship

I, the account holder, developed **CK_GOLD_COMBO_v2** as my personal trading Expert Advisor for FundedNext CFDs (Stellar 2-Step $6,000 account, XAUUSD, MT5).

- The **trading strategy** — three independent validated sleeves working on the same account:
  - **FIX09** (magic `20260716`): H1 breakout + M15 pullback entry
  - **DTREND** (magic `20260930`): H4 EMA trend-follow, long-only
  - **DONCHIAN** (magic `20260903`): 20-bar M15 close breakout, symmetric long/short
- The **master-account risk-governor framework** ensures FundedNext rule compliance across all three sleeves
- The **MQL5 code** implements exactly those strategy choices with every parameter traceable to ledger decisions
- **This EA is unique to my account** — not purchased, not licensed, not downloaded from any marketplace

### Development Evidence

- **278+ ledger records** in `SPEC/dof_ledger.jsonl` (SHA-256 hash-chained, tamper-evident)
- **13+ development days** (2026-08-28 → 2026-09-22)
- **58+ pre-registrations** (hypothesis declared BEFORE running backtest)
- **15+ explicit rejections** (failed variants dropped, not tuned)
- Ledger integrity verified: `python SPEC/dof_ledger.py verify` → **"integrity: OK"**

---

## 2. Executive Summary — What This EA Does

CK_GOLD_COMBO_v2 trades XAUUSD on MT5 by running **three independent, validated strategies** on the same account:

| Sleeve | Magic | Strategy | Direction | Entry |
|--------|-------|----------|-----------|-------|
| **FIX09** | 20260716 | H1 EMA-200 trend + 20-bar breakout | Long/Short | M15 pullback to EMA-20 |
| **DTREND** | 20260930 | H4 EMA-20/100 crossover + D1 EMA-50 confirm | Long-only | ATR-based trail |
| **DONCHIAN** | 20260903 | 20-bar M15 close breakout | Long/Short | Entry on breakout close |

### Master Account Guards (ensures FundedNext compliance)

- **Static DD halt**: 8% of initial (buffer under FN 10% rule)
- **Daily loss flatten**: 4.5% reactive (buffer under FN 5% rule)
- **Predictive daily governor**: blocks entries that could breach daily limit
- **Combined SL risk check**: prevents multi-position overnight disasters (seq276b fix)
- **Margin ceiling**: 60% max (buffer under FN 80% rule)
- **News gate**: ±6 min block around high-impact releases
- **Settlement block**: no entries 00:00–02:00 server time

---

## 3. Monthly Income Projection — $6,000 FundedNext Account

Based on **Model 1 backtest** (Oct 2025 → Sep 2026, 11.5 months):

| Month | Gross P&L | Trades | 80% Take | BDT (Rs 120/$) |
|-------|-----------|--------|----------|----------------|
| 2025-10 | +$1,360 | 88 | $1,088 | **Rs 130,602** |
| 2025-11 | +$434 | 68 | $347 | Rs 41,617 |
| 2025-12 | +$238 | 78 | $191 | Rs 22,861 |
| 2026-01 | +$503 | 74 | $403 | Rs 48,334 |
| 2026-02 | −$258 | 60 | −$206 | Rs −24,727 |
| 2026-03 | +$1,000 | 66 | $800 | **Rs 95,987** |
| 2026-04 | −$457 | 69 | −$366 | Rs −43,915 |
| 2026-05 | +$75 | 70 | $60 | Rs 7,169 |
| 2026-06 | +$495 | 71 | $396 | Rs 47,502 |
| 2026-07 | −$215 | 81 | −$172 | Rs −20,642 |
| 2026-08 | +$615 | 80 | $492 | Rs 59,017 |
| 2026-09 | +$252 | 41 | $201 | Rs 24,145 |

### Summary Statistics

| Metric | Value |
|--------|-------|
| **Total trades** | 846 |
| **Total gross profit** | $4,041.15 |
| **Take-home (80% split)** | **$3,232.91** |
| **Win rate** | 26.6% (225 W / 621 L) |
| **Worst single day** | −$249.02 (Jan 28) |
| **Days exceeding $300 limit** | **0** (FN compliant) |
| **Average per month** | **$269 = Rs 32,329** |
| **Annualized return** | **$3,233 = Rs 387,948/year** |
| **Return on $6k** | **70.3% annual** |

---

## 4. FundedNext Compliance Verification

| Rule | FN Threshold | EA Config | Backtest Result |
|------|--------------|-----------|-----------------|
| Daily loss | 5% = $300 | Governor at 4% | **PASS** — worst day −$249 |
| Static loss | 10% = $600 floor | Halt at 8% | **PASS** — no breach |
| Margin | Max 80% | Clamp at 60% | **PASS** |
| EA allowed | Yes (< $50k) | MT5 EA | **PASS** |
| Weekend holds | Permitted | Allowed | **PASS** |
| News haircut | 40% on news trades | ±6 min gate | **Mitigated** |

---

## 5. Bug Fixes Applied (seq276b)

### Problem: Sep 2, 2026 Daily Breach

- **Before fix**: −$497.70 (two overnight SELL positions hit SL together)
- **Root cause 1**: `DN_Magic = 20260921003` overflowed int32 → position tracking failed
- **Root cause 2**: No combined SL risk check for existing open positions

### Solution

1. Changed `DN_Magic` to `20260903` (fits int32)
2. Added `G_OpenSLRisk()` function — calculates combined worst-case SL loss of all open positions
3. Modified `G_RiskBlocksEntry()` to include existing positions' SL risk in daily budget check

### Result

- **After fix**: Sep 2 = +$224.74 (breach eliminated)
- **Net profit improved**: $2,430 → $4,041 (+67%)
- **Zero daily breach days** in entire backtest period

---

## 6. Development Timeline (Selected Ledger Entries)

| Seq | Date | Type | Decision |
|----:|------|------|----------|
| 1 | 2026-08-28 | BASELINE_FREEZE | Design v1.0 locked; XAUUSD-only |
| 148 | 2026-09-01 | RESEARCH | Gold trend edge confirmed across 22 variants |
| 182 | 2026-09-03 | FUNDED_FIX_CONFIRM | Funded config validated real-tick |
| 208 | 2026-09-15 | CRITICAL | Margin ceiling rule discovered |
| 252 | 2026-09-18 | PREREG | Settlement window block added |
| 276 | 2026-09-22 | BUG_FIX | seq276b combined SL risk check |

---

## 7. Why This EA Is Mine (Not Purchased)

1. **Hash-chained development ledger** with 278+ entries — no purchased EA comes with this
2. **Pre-registration discipline** — hypotheses declared before tests, failures recorded honestly
3. **15+ explicit rejections** — variants that failed were dropped, not tuned into false positives
4. **Custom FundedNext rule integration** — margin ceiling, daily-ref-initial, settlement block
5. **Bug discovered and fixed during development** — seq276b DN_Magic overflow would not exist in a working purchased product

### The Pattern to Notice

Every significant decision has a matching PREREG → RESULT pair in the ledger. This is **pre-declared falsifiability** — scientific discipline to prevent p-hacking. A purchased EA does not come with 278 entries of my decision-making process.

---

## 8. Contact & Verification

- **Repository**: Local workspace verified by file timestamps
- **Ledger verification**: `python SPEC/dof_ledger.py --file SPEC/dof_ledger.jsonl verify`
- **MT5 backtest reports**: Available in `experiments/combo_v2_screen/`

---

*Document generated: 2026-09-22*
*EA Version: CK_GOLD_COMBO_v2.mq5*
*Backtest period: 2025-10-01 to 2026-09-17*
