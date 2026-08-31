"""
Report Generator - Produces MT5-style backtest reports.
Includes all key metrics that MT5 Strategy Tester shows.
"""

import pandas as pd
import numpy as np
from typing import List, Dict
from datetime import datetime, timedelta
from backtest_engine import BacktestEngine, Deal
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from tabulate import tabulate
import os


class ReportGenerator:
    """Generates comprehensive MT5-style backtest reports."""
    
    def __init__(self, engine: BacktestEngine, strategy_name: str = "Strategy"):
        self.engine = engine
        self.strategy_name = strategy_name
        self.deals = engine.deals
        self.equity_curve = engine.equity_curve
    
    def generate_full_report(self, output_dir: str = "results") -> str:
        """Generate complete backtest report and save to files."""
        os.makedirs(output_dir, exist_ok=True)
        
        report_lines = []
        report_lines.append("=" * 80)
        report_lines.append(f"  BACKTEST REPORT: {self.strategy_name}")
        report_lines.append(f"  Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report_lines.append("=" * 80)
        report_lines.append("")
        
        # === SUMMARY STATISTICS ===
        stats = self._calculate_statistics()
        report_lines.append(self._format_summary(stats))
        
        # === TRADE LIST ===
        report_lines.append(self._format_trade_list())
        
        # === MONTHLY BREAKDOWN ===
        report_lines.append(self._format_monthly_breakdown())
        
        # === EQUITY CURVE ===
        self._plot_equity_curve(output_dir)
        
        # === TRADE DISTRIBUTION ===
        self._plot_trade_distribution(output_dir)
        
        full_report = "\n".join(report_lines)
        
        # Save report to file
        report_path = os.path.join(output_dir, "backtest_report.txt")
        with open(report_path, "w") as f:
            f.write(full_report)
        
        return full_report
    
    def _calculate_statistics(self) -> Dict:
        """Calculate all key trading statistics (MT5-style)."""
        deals = self.deals
        
        if not deals:
            return {"total_trades": 0}
        
        # Basic counts
        total_trades = len(deals)
        buy_trades = [d for d in deals if d.direction == "buy"]
        sell_trades = [d for d in deals if d.direction == "sell"]
        
        # Profit/Loss
        profits = [d.net_profit for d in deals]
        winning_trades = [d for d in deals if d.net_profit > 0]
        losing_trades = [d for d in deals if d.net_profit < 0]
        be_trades = [d for d in deals if d.net_profit == 0]
        
        total_profit = sum(profits)
        gross_profit = sum(d.net_profit for d in winning_trades)
        gross_loss = abs(sum(d.net_profit for d in losing_trades))
        
        # Win rate
        win_rate = (len(winning_trades) / total_trades * 100) if total_trades > 0 else 0
        
        # Profit factor
        profit_factor = (gross_profit / gross_loss) if gross_loss > 0 else float('inf')
        
        # Average trade
        avg_profit = total_profit / total_trades if total_trades > 0 else 0
        avg_win = gross_profit / len(winning_trades) if winning_trades else 0
        avg_loss = -gross_loss / len(losing_trades) if losing_trades else 0
        
        # Largest trades
        largest_win = max(profits) if profits else 0
        largest_loss = min(profits) if profits else 0
        
        # Consecutive wins/losses
        max_consec_wins, max_consec_losses = self._max_consecutive(deals)
        
        # Drawdown
        max_dd = self.engine.max_drawdown
        max_dd_pct = self.engine.max_drawdown_pct
        
        # Recovery factor
        recovery_factor = (total_profit / max_dd) if max_dd > 0 else float('inf')
        
        # Sharpe Ratio (annualized, assuming 252 trading days)
        if len(profits) > 1:
            daily_returns = self._calculate_daily_returns()
            if len(daily_returns) > 1 and np.std(daily_returns) > 0:
                sharpe = (np.mean(daily_returns) / np.std(daily_returns)) * np.sqrt(252)
            else:
                sharpe = 0
        else:
            sharpe = 0
        
        # Trade duration
        durations = [(d.close_time - d.open_time).total_seconds() / 3600 for d in deals]
        avg_duration_hours = np.mean(durations) if durations else 0
        
        # By direction
        buy_profit = sum(d.net_profit for d in buy_trades)
        sell_profit = sum(d.net_profit for d in sell_trades)
        buy_wins = len([d for d in buy_trades if d.net_profit > 0])
        sell_wins = len([d for d in sell_trades if d.net_profit > 0])
        
        # Close reasons
        sl_closes = len([d for d in deals if d.close_reason == "SL"])
        tp_closes = len([d for d in deals if d.close_reason == "TP"])
        be_closes = len([d for d in deals if d.close_reason == "BE"])
        other_closes = total_trades - sl_closes - tp_closes - be_closes
        
        # Commission and swap totals
        total_commission = sum(d.commission for d in deals)
        total_swap = sum(d.swap for d in deals)
        
        return {
            "total_trades": total_trades,
            "buy_trades": len(buy_trades),
            "sell_trades": len(sell_trades),
            "winning_trades": len(winning_trades),
            "losing_trades": len(losing_trades),
            "be_trades": len(be_trades),
            "win_rate": win_rate,
            "total_profit": total_profit,
            "gross_profit": gross_profit,
            "gross_loss": gross_loss,
            "profit_factor": profit_factor,
            "avg_profit": avg_profit,
            "avg_win": avg_win,
            "avg_loss": avg_loss,
            "largest_win": largest_win,
            "largest_loss": largest_loss,
            "max_consec_wins": max_consec_wins,
            "max_consec_losses": max_consec_losses,
            "max_drawdown": max_dd,
            "max_drawdown_pct": max_dd_pct,
            "recovery_factor": recovery_factor,
            "sharpe_ratio": sharpe,
            "avg_duration_hours": avg_duration_hours,
            "buy_profit": buy_profit,
            "sell_profit": sell_profit,
            "buy_win_rate": (buy_wins / len(buy_trades) * 100) if buy_trades else 0,
            "sell_win_rate": (sell_wins / len(sell_trades) * 100) if sell_trades else 0,
            "sl_closes": sl_closes,
            "tp_closes": tp_closes,
            "be_closes": be_closes,
            "other_closes": other_closes,
            "total_commission": total_commission,
            "total_swap": total_swap,
            "initial_deposit": self.engine.initial_deposit,
            "final_balance": self.engine.balance,
            "total_return_pct": ((self.engine.balance - self.engine.initial_deposit) / self.engine.initial_deposit) * 100,
        }
    
    def _max_consecutive(self, deals: List[Deal]) -> tuple:
        """Calculate max consecutive wins and losses."""
        max_wins = 0
        max_losses = 0
        current_wins = 0
        current_losses = 0
        
        for d in deals:
            if d.net_profit > 0:
                current_wins += 1
                current_losses = 0
                max_wins = max(max_wins, current_wins)
            elif d.net_profit < 0:
                current_losses += 1
                current_wins = 0
                max_losses = max(max_losses, current_losses)
            else:
                current_wins = 0
                current_losses = 0
        
        return max_wins, max_losses
    
    def _calculate_daily_returns(self) -> List[float]:
        """Calculate daily returns from equity curve."""
        if not self.equity_curve:
            return []
        
        df = pd.DataFrame(self.equity_curve)
        df['date'] = pd.to_datetime(df['time']).dt.date
        daily = df.groupby('date')['equity'].last()
        
        returns = daily.pct_change().dropna().tolist()
        return returns
    
    def _format_summary(self, stats: Dict) -> str:
        """Format summary statistics in MT5 style."""
        if stats["total_trades"] == 0:
            return "\n  *** NO TRADES EXECUTED ***\n"
        
        lines = []
        lines.append("─" * 80)
        lines.append("  SUMMARY STATISTICS")
        lines.append("─" * 80)
        lines.append("")
        
        # Account Performance
        lines.append("  ┌─ ACCOUNT PERFORMANCE ─────────────────────────────────────────────────────┐")
        lines.append(f"  │ Initial Deposit:          ${stats['initial_deposit']:>12,.2f}                           │")
        lines.append(f"  │ Final Balance:            ${stats['final_balance']:>12,.2f}                           │")
        lines.append(f"  │ Total Net Profit:         ${stats['total_profit']:>12,.2f}                           │")
        lines.append(f"  │ Total Return:              {stats['total_return_pct']:>11.2f}%                           │")
        lines.append(f"  │ Gross Profit:             ${stats['gross_profit']:>12,.2f}                           │")
        lines.append(f"  │ Gross Loss:              -${stats['gross_loss']:>12,.2f}                           │")
        lines.append(f"  │ Total Commission:        -${abs(stats['total_commission']):>12,.2f}                           │")
        lines.append(f"  │ Total Swap:               ${stats['total_swap']:>12,.2f}                           │")
        lines.append(f"  │ Profit Factor:             {stats['profit_factor']:>11.2f}                            │")
        lines.append(f"  │ Recovery Factor:           {stats['recovery_factor']:>11.2f}                            │")
        lines.append(f"  │ Sharpe Ratio:              {stats['sharpe_ratio']:>11.2f}                            │")
        lines.append(f"  │ Max Drawdown:             ${stats['max_drawdown']:>12,.2f} ({stats['max_drawdown_pct']:.2f}%)             │")
        lines.append(f"  └─────────────────────────────────────────────────────────────────────────────┘")
        lines.append("")
        
        # Trade Statistics
        lines.append("  ┌─ TRADE STATISTICS ─────────────────────────────────────────────────────────┐")
        lines.append(f"  │ Total Trades:              {stats['total_trades']:>8d}                                  │")
        lines.append(f"  │   Buy Trades:              {stats['buy_trades']:>8d}  (Win Rate: {stats['buy_win_rate']:.1f}%)              │")
        lines.append(f"  │   Sell Trades:             {stats['sell_trades']:>8d}  (Win Rate: {stats['sell_win_rate']:.1f}%)              │")
        lines.append(f"  │ Winning Trades:            {stats['winning_trades']:>8d}                                  │")
        lines.append(f"  │ Losing Trades:             {stats['losing_trades']:>8d}                                  │")
        lines.append(f"  │ Break-Even Trades:         {stats['be_trades']:>8d}                                  │")
        lines.append(f"  │ Win Rate:                  {stats['win_rate']:>7.1f}%                                  │")
        lines.append(f"  │ Average Trade:            ${stats['avg_profit']:>12,.2f}                           │")
        lines.append(f"  │ Average Win:              ${stats['avg_win']:>12,.2f}                           │")
        lines.append(f"  │ Average Loss:             ${stats['avg_loss']:>12,.2f}                           │")
        lines.append(f"  │ Largest Win:              ${stats['largest_win']:>12,.2f}                           │")
        lines.append(f"  │ Largest Loss:             ${stats['largest_loss']:>12,.2f}                           │")
        lines.append(f"  │ Max Consecutive Wins:      {stats['max_consec_wins']:>8d}                                  │")
        lines.append(f"  │ Max Consecutive Losses:    {stats['max_consec_losses']:>8d}                                  │")
        lines.append(f"  │ Avg Trade Duration:        {stats['avg_duration_hours']:>7.1f} hours                            │")
        lines.append(f"  └─────────────────────────────────────────────────────────────────────────────┘")
        lines.append("")
        
        # Close Reasons
        lines.append("  ┌─ CLOSE REASONS ────────────────────────────────────────────────────────────┐")
        lines.append(f"  │ Take Profit:              {stats['tp_closes']:>8d}                                  │")
        lines.append(f"  │ Stop Loss:                {stats['sl_closes']:>8d}                                  │")
        lines.append(f"  │ Break-Even:               {stats['be_closes']:>8d}                                  │")
        lines.append(f"  │ Other:                    {stats['other_closes']:>8d}                                  │")
        lines.append(f"  └─────────────────────────────────────────────────────────────────────────────┘")
        lines.append("")
        
        # Direction Breakdown
        lines.append("  ┌─ DIRECTION BREAKDOWN ──────────────────────────────────────────────────────┐")
        lines.append(f"  │ Buy Profit:              ${stats['buy_profit']:>12,.2f}                           │")
        lines.append(f"  │ Sell Profit:             ${stats['sell_profit']:>12,.2f}                           │")
        lines.append(f"  └─────────────────────────────────────────────────────────────────────────────┘")
        
        return "\n".join(lines)
    
    def _format_trade_list(self) -> str:
        """Format trade list table."""
        if not self.deals:
            return ""
        
        lines = []
        lines.append("")
        lines.append("─" * 80)
        lines.append("  TRADE LIST (All Deals)")
        lines.append("─" * 80)
        lines.append("")
        
        table_data = []
        for d in self.deals:
            duration = d.close_time - d.open_time
            hours = duration.total_seconds() / 3600
            
            # Determine price format based on digits
            digits = self.engine.symbol_info.digits
            price_fmt = f".{digits}f"
            
            table_data.append([
                d.ticket,
                d.open_time.strftime("%Y.%m.%d %H:%M"),
                d.direction.upper(),
                f"{d.volume:.2f}",
                f"{d.open_price:{price_fmt}}",
                f"{d.sl:{price_fmt}}" if d.sl > 0 else "-",
                f"{d.tp:{price_fmt}}" if d.tp > 0 else "-",
                d.close_time.strftime("%Y.%m.%d %H:%M"),
                f"{d.close_price:{price_fmt}}",
                d.close_reason,
                f"{d.commission:.2f}",
                f"{d.swap:.2f}",
                f"{d.net_profit:+.2f}",
                f"{hours:.1f}h",
            ])
        
        headers = ["#", "Open Time", "Dir", "Lots", "Open", "SL", "TP", 
                   "Close Time", "Close", "Reason", "Comm", "Swap", "Profit", "Dur"]
        
        lines.append(tabulate(table_data, headers=headers, tablefmt="simple"))
        
        return "\n".join(lines)
    
    def _format_monthly_breakdown(self) -> str:
        """Format monthly profit breakdown."""
        if not self.deals:
            return ""
        
        lines = []
        lines.append("")
        lines.append("─" * 80)
        lines.append("  MONTHLY BREAKDOWN")
        lines.append("─" * 80)
        lines.append("")
        
        # Group deals by month
        monthly_data = {}
        for d in self.deals:
            month_key = d.close_time.strftime("%Y-%m")
            if month_key not in monthly_data:
                monthly_data[month_key] = {"trades": 0, "profit": 0.0, "wins": 0, "losses": 0}
            monthly_data[month_key]["trades"] += 1
            monthly_data[month_key]["profit"] += d.net_profit
            if d.net_profit > 0:
                monthly_data[month_key]["wins"] += 1
            elif d.net_profit < 0:
                monthly_data[month_key]["losses"] += 1
        
        table_data = []
        cumulative = self.engine.initial_deposit
        for month, data in sorted(monthly_data.items()):
            cumulative += data["profit"]
            win_rate = (data["wins"] / data["trades"] * 100) if data["trades"] > 0 else 0
            table_data.append([
                month,
                data["trades"],
                data["wins"],
                data["losses"],
                f"{win_rate:.1f}%",
                f"${data['profit']:+.2f}",
                f"${cumulative:.2f}",
            ])
        
        headers = ["Month", "Trades", "Wins", "Losses", "Win%", "Profit", "Balance"]
        lines.append(tabulate(table_data, headers=headers, tablefmt="simple"))
        
        return "\n".join(lines)
    
    def _plot_equity_curve(self, output_dir: str):
        """Plot and save equity curve chart."""
        if not self.equity_curve:
            return
        
        df = pd.DataFrame(self.equity_curve)
        df['time'] = pd.to_datetime(df['time'])
        
        fig, axes = plt.subplots(2, 1, figsize=(14, 8), gridspec_kw={'height_ratios': [3, 1]})
        
        # Equity & Balance curve
        ax1 = axes[0]
        ax1.plot(df['time'], df['equity'], color='#2196F3', linewidth=1, label='Equity', alpha=0.8)
        ax1.plot(df['time'], df['balance'], color='#4CAF50', linewidth=1.5, label='Balance')
        ax1.axhline(y=self.engine.initial_deposit, color='gray', linestyle='--', alpha=0.5, label='Initial Deposit')
        ax1.fill_between(df['time'], df['equity'], self.engine.initial_deposit, 
                        where=df['equity'] >= self.engine.initial_deposit, 
                        color='green', alpha=0.1)
        ax1.fill_between(df['time'], df['equity'], self.engine.initial_deposit, 
                        where=df['equity'] < self.engine.initial_deposit, 
                        color='red', alpha=0.1)
        ax1.set_title(f'{self.strategy_name} - Equity Curve', fontsize=14, fontweight='bold')
        ax1.set_ylabel('Account Value ($)')
        ax1.legend(loc='upper left')
        ax1.grid(True, alpha=0.3)
        ax1.xaxis.set_major_formatter(mdates.DateFormatter('%Y-%m'))
        
        # Drawdown
        ax2 = axes[1]
        # Calculate running drawdown
        peak = df['equity'].expanding().max()
        dd = (df['equity'] - peak)
        dd_pct = (dd / peak) * 100
        
        ax2.fill_between(df['time'], dd_pct, 0, color='red', alpha=0.4)
        ax2.plot(df['time'], dd_pct, color='darkred', linewidth=0.8)
        ax2.set_title('Drawdown %', fontsize=11)
        ax2.set_ylabel('Drawdown (%)')
        ax2.set_xlabel('Date')
        ax2.grid(True, alpha=0.3)
        ax2.xaxis.set_major_formatter(mdates.DateFormatter('%Y-%m'))
        
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, 'equity_curve.png'), dpi=150, bbox_inches='tight')
        plt.close()
    
    def _plot_trade_distribution(self, output_dir: str):
        """Plot trade profit distribution."""
        if not self.deals:
            return
        
        profits = [d.net_profit for d in self.deals]
        
        fig, axes = plt.subplots(1, 2, figsize=(14, 5))
        
        # Profit distribution histogram
        ax1 = axes[0]
        colors = ['green' if p > 0 else 'red' for p in profits]
        ax1.bar(range(len(profits)), profits, color=colors, alpha=0.7)
        ax1.axhline(y=0, color='black', linewidth=0.5)
        ax1.set_title('Trade Results (Chronological)', fontsize=12)
        ax1.set_xlabel('Trade #')
        ax1.set_ylabel('Profit ($)')
        ax1.grid(True, alpha=0.3)
        
        # Profit histogram
        ax2 = axes[1]
        ax2.hist(profits, bins=min(30, len(profits)), color='steelblue', edgecolor='white', alpha=0.8)
        ax2.axvline(x=0, color='red', linestyle='--', linewidth=1)
        ax2.axvline(x=np.mean(profits), color='green', linestyle='-', linewidth=2, label=f'Mean: ${np.mean(profits):.2f}')
        ax2.set_title('Profit Distribution', fontsize=12)
        ax2.set_xlabel('Profit ($)')
        ax2.set_ylabel('Frequency')
        ax2.legend()
        ax2.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, 'trade_distribution.png'), dpi=150, bbox_inches='tight')
        plt.close()
