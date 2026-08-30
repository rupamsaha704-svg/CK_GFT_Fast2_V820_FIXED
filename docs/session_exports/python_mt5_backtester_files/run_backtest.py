"""
Main Backtest Runner - CK_GFT_Fast2_V20_Funded Strategy
========================================================
Runs the complete backtest and generates MT5-style report.

Usage:
    python run_backtest.py

To use with real MT5 data:
    1. Export M5 data from MT5 (File -> Save as CSV)
    2. Place the CSV file in ./data/ folder
    3. Set DATA_SOURCE = "csv" and CSV_PATH = "data/your_file.csv"
"""

import sys
import os
import time
from datetime import datetime

# Add project root to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from symbol_info import SymbolInfo
from data_loader import generate_realistic_m5_data, save_data, load_data
from backtest_engine import BacktestEngine
from strategy_ck_gft import CKGFTStrategy
from report_generator import ReportGenerator

# ============================================================
# CONFIGURATION - Match your MT5 Strategy Tester settings
# ============================================================

# Symbol Configuration
SYMBOL = "XAUUSD"
CUSTOM_SYMBOL_PROPS = {
    "digits": 2,
    "point": 0.01,
    "tick_size": 0.01,
    "tick_value": 1.0,          # $1 per tick (0.01) per 1 lot (100 oz)
    "contract_size": 100,       # 100 troy ounces per lot
    "volume_min": 0.01,
    "volume_max": 50.0,
    "volume_step": 0.01,
    "spread_avg": 25,           # Average spread in points (25 cents)
    "spread_min": 15,
    "spread_max": 80,
    "stops_level": 0,
    "freeze_level": 0,
    "commission_per_lot": 0.0,  # Commission per lot (round trip)
    "swap_long": -43.0,         # Daily swap for long XAUUSD (per lot)
    "swap_short": 7.0,          # Daily swap for short XAUUSD (per lot)
    "trade_mode": "cfd",
}

# Account Configuration
INITIAL_DEPOSIT = 5000.0       # Starting balance
LEVERAGE = 30                  # Account leverage (1:30) as shown in MT5
SLIPPAGE_POINTS = 5            # Slippage simulation (50ms delay ~ 5 points on gold)

# Backtest Period (matching MT5 Strategy Tester settings)
START_DATE = "2026-01-01"
END_DATE = "2026-07-24"

# Data Source - Using REAL MT5 exported data
DATA_SOURCE = "csv"
CSV_PATH = "data/XAUUSD_M5_real.csv"

# Strategy Parameters (matching your MQL5 EA inputs)
STRATEGY_PARAMS = {
    "magic": 20260715,
    "risk_percent": 0.70,
    "rr": 2.0,
    "break_even_at_1r": True,
    "max_trades_per_day": 4,
    "daily_loss_stop_r": 1.5,
    "daily_profit_stop_r": 5.0,
    "max_spread_points": 50,
    "max_lot": 0.08,
    "use_trend": True,
    "ema_fast_period": 21,
    "ema_slow_period": 50,
    "knee_min_run_buy": 2,
    "min_body_ratio_buy": 0.60,
    "knee_min_run_sell": 3,
    "min_body_ratio_sell": 0.70,
    "valid_bars": 5,
    "sl_buffer_atr": 0.3,
    "min_sl_points": 5.0,
    "atr_period": 14,
}


def main():
    print("=" * 80)
    print("  CK_GFT_Fast2_V20_Funded - Python Backtester")
    print("  Realistic MT5 Strategy Tester Simulation")
    print("=" * 80)
    print()
    
    start_time = time.time()
    
    # === Step 1: Setup Symbol Info ===
    print("[1/5] Setting up symbol information...")
    symbol_info = SymbolInfo(SYMBOL, CUSTOM_SYMBOL_PROPS)
    print(f"  Symbol: {SYMBOL}")
    print(f"  Digits: {symbol_info.digits}")
    print(f"  Point: {symbol_info.point}")
    print(f"  Tick Value: ${symbol_info.tick_value}")
    print(f"  Contract Size: {symbol_info.contract_size}")
    print(f"  Spread (avg): {symbol_info.spread_avg} points ({symbol_info.spread_avg/10:.1f} pips)")
    print()
    
    # === Step 2: Load/Generate Data ===
    print("[2/5] Loading historical data...")
    
    data_file = f"data/{SYMBOL}_M5_backtest.csv"
    
    if DATA_SOURCE == "csv" and os.path.exists(CSV_PATH):
        from data_loader import load_csv_data
        df = load_csv_data(CSV_PATH, start_date=START_DATE, end_date=END_DATE)
        print(f"  Loaded REAL MT5 data from: {CSV_PATH}")
    elif os.path.exists(data_file):
        df = load_data(data_file)
        print(f"  Loaded cached data from: {data_file}")
    else:
        # Set base price and daily range based on symbol
        if SYMBOL == "XAUUSD":
            base_price = 2650.00   # Gold price range for 2026
            avg_daily_range = 3500.0  # Gold daily range in points (3500 points = $35.00)
        elif SYMBOL == "EURUSD":
            base_price = 1.0800
            avg_daily_range = 60.0  # 60 pips
        elif SYMBOL == "GBPUSD":
            base_price = 1.2700
            avg_daily_range = 80.0
        else:
            base_price = 1.0000
            avg_daily_range = 50.0
        
        df = generate_realistic_m5_data(
            symbol=SYMBOL,
            start_date=START_DATE,
            end_date=END_DATE,
            base_price=base_price,
            avg_daily_range_pips=avg_daily_range,
            avg_spread_points=symbol_info.spread_avg,
            seed=42  # Reproducible results
        )
        save_data(df, data_file)
    
    print(f"  Total bars: {len(df):,}")
    print(f"  Period: {df.index[0]} to {df.index[-1]}")
    print()
    
    # === Step 3: Initialize Engine & Strategy ===
    print("[3/5] Initializing backtest engine...")
    
    engine = BacktestEngine(
        symbol_info=symbol_info,
        initial_deposit=INITIAL_DEPOSIT,
        leverage=LEVERAGE,
        commission_per_lot=CUSTOM_SYMBOL_PROPS.get("commission_per_lot", 0.0),
        slippage_points=SLIPPAGE_POINTS,
        swap_enabled=True,
    )
    
    strategy = CKGFTStrategy(
        engine=engine,
        symbol_info=symbol_info,
        **STRATEGY_PARAMS
    )
    
    print(f"  Initial Deposit: ${INITIAL_DEPOSIT:,.2f}")
    print(f"  Leverage: 1:{LEVERAGE}")
    print(f"  Risk per trade: {STRATEGY_PARAMS['risk_percent']}%")
    print(f"  Risk:Reward: 1:{STRATEGY_PARAMS['rr']}")
    print(f"  Max lot: {STRATEGY_PARAMS['max_lot']}")
    print(f"  Break-even at 1R: {STRATEGY_PARAMS['break_even_at_1r']}")
    print()
    
    # === Step 4: Run Backtest ===
    print("[4/5] Running backtest...")
    print(f"  Processing {len(df):,} bars...")
    
    bar_count = 0
    progress_interval = len(df) // 10  # Print progress every 10%
    
    for bar_time, bar_data in df.iterrows():
        bar_count += 1
        
        # Convert bar to dict for strategy
        bar_dict = {
            'open': bar_data['open'],
            'high': bar_data['high'],
            'low': bar_data['low'],
            'close': bar_data['close'],
            'tick_volume': bar_data.get('tick_volume', 100),
            'spread': int(bar_data.get('spread', symbol_info.spread_avg)),
        }
        
        # Process bar in engine (update market, check SL/TP, swap)
        engine.process_bar(bar_data, bar_time)
        
        # Run strategy logic
        strategy.on_bar(bar_dict, bar_time)
        
        # Progress
        if progress_interval > 0 and bar_count % progress_interval == 0:
            pct = (bar_count / len(df)) * 100
            trades = len(engine.deals)
            positions = len(engine.positions)
            print(f"    {pct:.0f}% complete | Bars: {bar_count:,} | Trades closed: {trades} | Open: {positions} | Balance: ${engine.balance:.2f}")
    
    # Close any remaining positions at market
    for pos in list(engine.positions):
        if pos.direction == "buy":
            engine.close_position(pos, engine.current_bid, "End of Test")
        else:
            engine.close_position(pos, engine.current_ask, "End of Test")
    
    elapsed = time.time() - start_time
    print(f"\n  Backtest completed in {elapsed:.2f} seconds")
    print(f"  Total deals: {len(engine.deals)}")
    print()
    
    # === Step 5: Generate Report ===
    print("[5/5] Generating report...")
    
    reporter = ReportGenerator(engine, strategy_name="CK_GFT_Fast2_V20_Funded")
    report = reporter.generate_full_report(output_dir="results")
    
    print(report)
    
    print("\n" + "=" * 80)
    print("  FILES SAVED:")
    print(f"  - results/backtest_report.txt  (Full text report)")
    print(f"  - results/equity_curve.png     (Equity & Drawdown chart)")
    print(f"  - results/trade_distribution.png (Trade analysis)")
    print(f"  - {data_file}                  (Market data cache)")
    print("=" * 80)
    
    return engine, strategy


if __name__ == "__main__":
    engine, strategy = main()
