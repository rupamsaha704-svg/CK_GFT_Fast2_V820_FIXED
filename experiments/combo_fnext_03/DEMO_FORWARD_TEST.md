# DEMO FORWARD-TEST — Plan C on a free broker demo (no money required)

Purpose: run the SAME EA (Plan C, `CK_GOLD_COMBO` FIX 0.02) on a free broker demo
account so we gather 2–4 weeks of REAL-TIME live-tick evidence before you spend a
single rupee on the FundedNext challenge. When you're ready to buy FN, you'll
already know:

- The EA runs correctly on live ticks (no execution errors, no wrong-side entries).
- The daily / static / margin guards trigger as designed.
- The trade cadence and win-rate on live look like the backtest (or if they don't,
  we diagnose BEFORE risking money).

**Cost: zero.** Any broker's MT5 demo is free. The EA and preset are already
installed on this PC by `install_combo_fnext.ps1` (`.ex5` in
`AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\`).

## Step 1 — get a demo account (2 minutes)

**Recommended broker (India-friendly, free demo, tight XAUUSD spread):**

- **Exness** — go to `exness.com`, sign up, choose "Try Demo Account", pick MT5.
  You'll get: server name, login number, investor password, master password.
  Save these — you'll need them in step 2.

Alternatives that also work: XM, IC Markets, Pepperstone. Any broker whose MT5
demo offers XAUUSD is fine. **Do NOT use the built-in MetaQuotes-Demo** — it uses
synthetic prices that don't match real gold, so the forward-test won't reflect
reality.

## Step 2 — attach the demo account to MT5

1. Open MT5 (it's already installed at `C:\Program Files\MetaTrader 5\`).
2. **File → Open an Account** (or Ctrl+F5).
3. In the "Search brokers" box type your broker name (e.g. "Exness"). Pick the
   result that matches your signup.
4. Choose **"Connect with an existing trade account"** (you already have the
   login from step 1). Enter your login + master password + server. Click Finish.
5. Bottom-right of MT5 should show green connection + your demo balance (usually
   $10,000 or $100,000 default demo capital).

If your demo balance is NOT $6,000 — that's OK. The EA reads whatever balance the
account has and uses it as the initial. Percentage guards work the same. For
apples-to-apples with FN, you can adjust the demo balance to $6,000 via most
broker web dashboards, or just let it be $10k / $100k and mentally scale the
income numbers.

## Step 3 — attach the EA

1. In MT5 open a XAUUSD chart (right-click Market Watch → Show All → double-click
   XAUUSD).
2. Change timeframe to **M15**.
3. In the left "Navigator" pane, expand **Expert Advisors** → find
   `CK_GOLD_COMBO`. Drag it onto the XAUUSD M15 chart.
4. In the input dialog that pops up:
   - Click **Load** (bottom-left).
   - Pick `CK_GOLD_COMBO_FundedNext` from the list.
   - Verify the key values loaded:
     - `Combo_Stage = 0` (Eval mode)
     - `Combo_DailyRefInitial = true`
     - `Combo_BlockEntryHours = 0,1`
     - `FIX_FixedLot = 0.02`
     - `Combo_UseNewsGate = true`
5. Tick **"Allow Algo Trading"** checkbox in the same dialog.
6. Click **OK**.
7. Top toolbar: click the **AutoTrading** button (should turn green).
8. Look at the chart — top-right corner should show a smiley face (EA is running).
9. Open **Terminal → Experts** tab (Ctrl+T then click Experts). You should see a
   line like:
   ```
   [COMBO] init bal=10000.00 login=... MODE=EVAL FIX09=on DTREND=on staticDDstop=8.0% dailyLoss=4.5%
   ```

If that line appears → the EA is live and armed. It will now wait for a valid
signal and trade automatically on new bar closes.

## Step 4 — leave it running

- **Keep MT5 open.** If you close MT5, the EA stops. Fine to minimize to system
  tray, just don't quit the application.
- **Don't touch the settings.** Any change to inputs invalidates the forward-test.
- **Don't manually close positions** unless the emergency conditions in
  `DEPLOY_CHECKLIST.md` trigger. Let the EA manage exits.

## Step 5 — daily check (5 minutes)

Same as `DEPLOY_CHECKLIST.md` daily section, but without the FN dashboard part
(demo has no FN rules). Just check:

- MT5 open, smiley face on chart, no error toasts.
- Experts tab: no red errors in the last 24 hours.
- Positions tab: how many open, how are they doing.
- History tab: any closed trades since yesterday?

Note the numbers in a personal log — even a WhatsApp message to yourself works.

## Step 6 — weekly check (15 minutes)

- Open History → right-click → **Save as Report** → HTML. Save as
  `demo_wkNN.html`.
- Or copy `ck_gold_combo_deals.csv` from
  `C:\Users\prita\AppData\Roaming\MetaQuotes\Terminal\Common\Files\`. This CSV
  is what the analyzer scripts read.
- Send it to me. I'll run `_compare_plans.py` and tell you whether the live edge
  matches the backtest.

## Step 7 — how long to run

**Minimum: 2 weeks + at least 10 closed trades.** That's enough to see whether
the EA is fundamentally healthy on live ticks. If both hold, we're green to
buy the FN challenge.

**Comfortable: 4 weeks + 20+ trades.** More live data = more confidence.

## What "PASS" looks like on the demo

- EA executes trades correctly (no wrong-side, no runaway positions).
- No repeated error messages in Experts tab.
- Trade cadence roughly matches the backtest (~1 trade per trading day, some
  clusters, some quiet weeks).
- Win-rate on the demo within about ±10 percentage points of the backtest 25.6%.
- Master guards do their job — no daily-loss halt from noise, no static-DD halt
  unless something goes seriously wrong.

## What "FAIL" looks like — pause and message back

- EA doesn't fire any trades for 5+ trading days (likely input mistake or feed
  issue).
- Repeated error retcodes in the Experts log.
- Positions opening / closing on their own with no signal explanation.
- Any daily-loss halt or static-DD halt on the demo — investigate before
  spending money on FN.

## Meanwhile — parallel work

While the demo runs, we can:

- Pre-register + test the **Asian-session range fade** candidate (Path B). If it
  passes, we have a second uncorrelated edge ready when the FN challenge starts.
- Continue the QM native rewrite (blocks 2–7). Free, robustness building.
- Save for the FN challenge fee (~$60–70).

## When you're ready to buy FN

1. Buy Stellar 2-Step $6,000 on the FN client area.
2. Choose EA+VPS bundle at checkout ($10 one-time).
3. Choose Standard 80% or On-Demand 90% payout at checkout — see
   `SPEC/PLAN_C_vs_PLAN_Q.md` §1.6 for the pick.
4. Log the FN account into MT5 (File → Open an Account).
5. Detach the EA from the demo chart, attach it to the same XAUUSD M15 chart on
   the FN account. Load the same preset.
6. Everything is now on the FN account — no new install needed, we already have
   the .ex5 built.

The demo forward-test doesn't waste anything. It's the same EA on the same
strategy on the same market — just on paper money until you can afford the
challenge fee.
