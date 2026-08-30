"""
=============================================================
INSTITUTIONAL PROP FIRM EA - BACKTEST ANALYZER
=============================================================
This script connects to MetaTrader 5, pulls trade history,
and generates a professional analysis report.

HOW TO USE:
1. Make sure MT5 is open and logged in
2. Run this script: python backtest_analyzer.py
3. It will show analysis in terminal and save report

REQUIREMENTS:
pip install pandas matplotlib MetaTrader5 numpy

CAVEAT (recorded in session export): this reads the LIVE terminal account
history, NOT the Strategy-Tester deals. An MT5 HTML-report parser was
promised but NOT built. Magic number is hard-coded to 30300001.
=============================================================
"""

import MetaTrader5 as mt5
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import os

# ============================================================
# CONFIGURATION
# ============================================================
MAGIC_NUMBER = 30300001  # Your EA's magic number (Institutional_PropFirm_EA_V3)
INITIAL_BALANCE = 5000.0
SYMBOL = "XAUUSD"

# ============================================================
# CONNECT TO MT5
# ============================================================
def connect_mt5():
    if not mt5.initialize():
        print("ERROR: MT5 initialization failed!")
        print("Make sure MetaTrader 5 is open and running.")
        print(f"Error: {mt5.last_error()}")
        return False

    account_info = mt5.account_info()
    if account_info is None:
        print("ERROR: Cannot get account info!")
        return False

    print("="*60)
    print("  CONNECTED TO MT5")
    print("="*60)
    print(f"  Account: {account_info.login}")
    print(f"  Server:  {account_info.server}")
    print(f"  Balance: ${account_info.balance:.2f}")
    print(f"  Equity:  ${account_info.equity:.2f}")
    print("="*60)
    return True

# ============================================================
# GET TRADE HISTORY
# ============================================================
def get_trade_history(days_back=365):
    """Get all closed deals for our EA"""

    date_from = datetime.now() - timedelta(days=days_back)
    date_to = datetime.now()

    deals = mt5.history_deals_get(date_from, date_to)

    if deals is None or len(deals) == 0:
        print("No deals found in history.")
        print("Try running a backtest first, then check the account history.")
        return None

    df = pd.DataFrame(list(deals), columns=deals[0]._asdict().keys())

    # Filter by magic number and entry type (OUT = closed trades)
    df_ea = df[(df['magic'] == MAGIC_NUMBER) & (df['entry'] == 1)]  # 1 = DEAL_ENTRY_OUT

    if len(df_ea) == 0:
        print(f"No closed trades found for Magic Number {MAGIC_NUMBER}")
        print(f"Total deals in history: {len(df)}")
        print(f"Unique magic numbers: {df['magic'].unique()}")
        return None

    print(f"\nFound {len(df_ea)} closed trades for Magic #{MAGIC_NUMBER}")
    return df_ea

# ============================================================
# ANALYZE TRADES
# ============================================================
def analyze_trades(df):
    """Perform complete analysis"""

    if df is None or len(df) == 0:
        print("No data to analyze!")
        return

    print("\n" + "="*60)
    print("  TRADE ANALYSIS REPORT")
    print("="*60)

    total_trades = len(df)
    wins = df[df['profit'] > 0]
    losses = df[df['profit'] < 0]
    breakeven = df[df['profit'] == 0]

    win_count = len(wins)
    loss_count = len(losses)
    win_rate = (win_count / total_trades * 100) if total_trades > 0 else 0

    total_profit = df['profit'].sum()
    gross_profit = wins['profit'].sum() if len(wins) > 0 else 0
    gross_loss = abs(losses['profit'].sum()) if len(losses) > 0 else 0

    profit_factor = (gross_profit / gross_loss) if gross_loss > 0 else 999

    avg_win = wins['profit'].mean() if len(wins) > 0 else 0
    avg_loss = losses['profit'].mean() if len(losses) > 0 else 0

    expectancy = (win_rate/100 * avg_win) + ((1 - win_rate/100) * avg_loss)

    cumulative = df['profit'].cumsum()
    running_max = cumulative.cummax()
    drawdown = running_max - cumulative
    max_dd = drawdown.max()
    max_dd_pct = (max_dd / INITIAL_BALANCE * 100) if INITIAL_BALANCE > 0 else 0

    recovery_factor = (total_profit / max_dd) if max_dd > 0 else 999
    rr_ratio = (avg_win / abs(avg_loss)) if avg_loss != 0 else 999

    print(f"\n--- OVERVIEW ---")
    print(f"  Total Trades:      {total_trades}")
    print(f"  Wins:              {win_count} ({win_rate:.1f}%)")
    print(f"  Losses:            {loss_count} ({100-win_rate:.1f}%)")
    print(f"  Break-even:        {len(breakeven)}")

    print(f"\n--- PROFIT ---")
    print(f"  Net Profit:        ${total_profit:.2f}")
    print(f"  Gross Profit:      ${gross_profit:.2f}")
    print(f"  Gross Loss:        -${gross_loss:.2f}")
    print(f"  Profit Factor:     {profit_factor:.2f}")

    print(f"\n--- AVERAGES ---")
    print(f"  Avg Win:           ${avg_win:.2f}")
    print(f"  Avg Loss:          ${avg_loss:.2f}")
    print(f"  Avg RR Ratio:      1:{rr_ratio:.2f}")
    print(f"  Expectancy:        ${expectancy:.2f} per trade")

    print(f"\n--- RISK ---")
    print(f"  Max Drawdown:      ${max_dd:.2f} ({max_dd_pct:.2f}%)")
    print(f"  Recovery Factor:   {recovery_factor:.2f}")

    print(f"\n--- TIME ANALYSIS ---")
    df_copy = df.copy()
    df_copy['time_dt'] = pd.to_datetime(df_copy['time'], unit='s')
    df_copy['hour'] = df_copy['time_dt'].dt.hour
    df_copy['weekday'] = df_copy['time_dt'].dt.day_name()

    hour_profit = df_copy.groupby('hour')['profit'].sum()
    if len(hour_profit) > 0:
        best_hour = hour_profit.idxmax()
        worst_hour = hour_profit.idxmin()
        print(f"  Best Hour:         {best_hour}:00 (${hour_profit[best_hour]:.2f})")
        print(f"  Worst Hour:        {worst_hour}:00 (${hour_profit[worst_hour]:.2f})")

    day_profit = df_copy.groupby('weekday')['profit'].sum()
    if len(day_profit) > 0:
        best_day = day_profit.idxmax()
        worst_day = day_profit.idxmin()
        print(f"  Best Day:          {best_day} (${day_profit[best_day]:.2f})")
        print(f"  Worst Day:         {worst_day} (${day_profit[worst_day]:.2f})")

    print(f"\n--- DIRECTION ANALYSIS ---")
    buys = df[df['type'] == 0]   # 0 = BUY
    sells = df[df['type'] == 1]  # 1 = SELL

    buy_profit = buys['profit'].sum() if len(buys) > 0 else 0
    sell_profit = sells['profit'].sum() if len(sells) > 0 else 0
    buy_wins = len(buys[buys['profit'] > 0])
    sell_wins = len(sells[sells['profit'] > 0])
    buy_wr = (buy_wins / len(buys) * 100) if len(buys) > 0 else 0
    sell_wr = (sell_wins / len(sells) * 100) if len(sells) > 0 else 0

    print(f"  BUY:  {len(buys)} trades | WR: {buy_wr:.0f}% | Profit: ${buy_profit:.2f}")
    print(f"  SELL: {len(sells)} trades | WR: {sell_wr:.0f}% | Profit: ${sell_profit:.2f}")

    print(f"\n--- CONSECUTIVE ---")
    max_consec_wins = 0
    max_consec_losses = 0
    current_streak = 0

    for profit in df['profit']:
        if profit > 0:
            current_streak = current_streak + 1 if current_streak > 0 else 1
            max_consec_wins = max(max_consec_wins, current_streak)
        elif profit < 0:
            current_streak = current_streak - 1 if current_streak < 0 else -1
            max_consec_losses = max(max_consec_losses, abs(current_streak))

    print(f"  Max Consec Wins:   {max_consec_wins}")
    print(f"  Max Consec Losses: {max_consec_losses}")

    print(f"\n{'='*60}")
    print(f"  VERDICT")
    print(f"{'='*60}")

    score = 0
    issues = []

    if total_trades >= 200:
        score += 2; print(f"  [OK] Enough trades ({total_trades})")
    elif total_trades >= 50:
        score += 1; print(f"  [~] Moderate trades ({total_trades}) - need 200+")
    else:
        issues.append(f"Only {total_trades} trades - need 200+")
        print(f"  [X] Too few trades ({total_trades}) - NEED 200+")

    if profit_factor >= 1.5:
        score += 2; print(f"  [OK] Good Profit Factor ({profit_factor:.2f})")
    elif profit_factor >= 1.2:
        score += 1; print(f"  [~] Moderate PF ({profit_factor:.2f}) - want 1.5+")
    else:
        issues.append(f"Low Profit Factor: {profit_factor:.2f}")
        print(f"  [X] Low Profit Factor ({profit_factor:.2f})")

    if max_dd_pct <= 6:
        score += 2; print(f"  [OK] Good Drawdown ({max_dd_pct:.1f}%)")
    elif max_dd_pct <= 8:
        score += 1; print(f"  [~] Moderate DD ({max_dd_pct:.1f}%) - want <6%")
    else:
        issues.append(f"High Drawdown: {max_dd_pct:.1f}%")
        print(f"  [X] High Drawdown ({max_dd_pct:.1f}%)")

    if recovery_factor >= 2:
        score += 2; print(f"  [OK] Good Recovery Factor ({recovery_factor:.2f})")
    elif recovery_factor >= 1:
        score += 1; print(f"  [~] Moderate RF ({recovery_factor:.2f}) - want 2+")
    else:
        issues.append(f"Low Recovery Factor: {recovery_factor:.2f}")
        print(f"  [X] Low Recovery Factor ({recovery_factor:.2f})")

    if win_rate >= 45:
        score += 1; print(f"  [OK] Good Win Rate ({win_rate:.1f}%)")
    else:
        issues.append(f"Low Win Rate: {win_rate:.1f}%")
        print(f"  [~] Low Win Rate ({win_rate:.1f}%) - OK if RR high")

    print(f"\n  SCORE: {score}/9")

    if score >= 7:
        print(f"  READY for Prop Firm Challenge (with caution)")
    elif score >= 5:
        print(f"  PROMISING - needs more testing/optimization")
    else:
        print(f"  NOT READY - needs significant improvement")

    if issues:
        print(f"\n  ISSUES TO FIX:")
        for issue in issues:
            print(f"    -> {issue}")

    print(f"\n--- RECOMMENDATIONS ---")
    if total_trades < 50:
        print("  1. Run longer backtest (1-2 years minimum)")
    if win_rate < 40 and rr_ratio < 2:
        print("  2. Improve entry confirmation (win rate too low for this RR)")
    if buy_wr < 30:
        print("  3. BUY logic has problems - check EMA/structure for longs")
    if sell_wr < 30:
        print("  4. SELL logic has problems - check EMA/structure for shorts")
    if max_dd_pct > 8:
        print("  5. Reduce risk % or tighten SL to lower drawdown")
    if max_consec_losses >= 5:
        print("  6. Add better cooldown after consecutive losses")

    print(f"\n{'='*60}")
    print(f"  Report generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print(f"{'='*60}")

    return {
        'total_trades': total_trades,
        'win_rate': win_rate,
        'profit_factor': profit_factor,
        'max_dd_pct': max_dd_pct,
        'recovery_factor': recovery_factor,
        'expectancy': expectancy,
        'score': score
    }

# ============================================================
# MAIN
# ============================================================
if __name__ == "__main__":
    print("\n")
    print("="*60)
    print("  INSTITUTIONAL PROP FIRM EA - BACKTEST ANALYZER")
    print("  Version 1.0")
    print("="*60)

    if not connect_mt5():
        print("\nCannot connect to MT5.")
        print("Make sure MetaTrader 5 is open and you are logged in.")
        input("\nPress Enter to exit...")
        mt5.shutdown()
        exit()

    df = get_trade_history(days_back=365)

    if df is not None and len(df) > 0:
        results = analyze_trades(df)
    else:
        print("\nNo trades found!")
        print("Possible reasons:")
        print("  1. EA hasn't traded yet on this account")
        print("  2. Magic number doesn't match")
        print(f"     Current magic: {MAGIC_NUMBER}")
        print("  3. Trades are from Strategy Tester (not live account)")

    mt5.shutdown()
    print("\n")
    input("Press Enter to exit...")
