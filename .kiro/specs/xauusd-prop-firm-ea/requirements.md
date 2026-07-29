# Requirements Document: XAUUSD Prop Firm EA (Hybrid V20 + Trailing)

## Introduction

This Expert Advisor implements a knee breakout trading strategy for XAUUSD on the M5 timeframe, designed to pass a Goat Funded Trader 5K 2-Step prop firm challenge. The system combines entry logic based on multi-bar knee patterns with a hybrid exit strategy featuring both fixed take-profit and trailing stop mechanisms. Key constraints include strict drawdown limits (5% daily, 10% total), daily trade limits (max 4), and lot size caps (0.05–0.08). The EA operates on M5 timeframe and implements regime detection using ADX to filter out ranging markets where knee breakouts historically fail.

## Glossary

- **XAUUSD**: Gold/US Dollar currency pair (trading instrument)
- **M5**: 5-minute timeframe
- **Knee Breakout**: Pattern where a run of same-direction bars is followed by a "knee" (reversal bar) and subsequent breakout
- **Buy Knee**: Bullish setup requiring 2+ green bars → red knee → price breakout above knee high
- **Sell Knee**: Bearish setup requiring 3+ red bars → green knee → price breakout below knee low (stricter rules)
- **Hybrid Exit**: Combination of fixed take-profit at 2.0× risk and trailing stop at 6× ATR
- **Break-Even (BE)**: Stop loss moved to entry price when position reaches 1R profit
- **Regime Filter**: ADX-based classification of trending vs ranging markets
- **R**: Risk amount (1R = distance from entry to stop loss in dollar terms)
- **DD**: Drawdown (peak-to-trough decline in equity)
- **Prop Firm**: Goat Funded Trader 5K 2-Step challenge (Phase 1: 10% profit, Phase 2: 5% profit)
- **Daily Loss Limit**: 1.5R (1.5× average trade risk) per calendar day

## Requirements

### Requirement 1: Daily Drawdown Protection

**User Story:** As a trader, I want the EA to enforce strict daily drawdown limits, so that I don't exceed prop firm constraints and lose my account.

#### Acceptance Criteria

1. WHEN daily equity drawdown reaches 5% of day-start balance THEN THE EA SHALL block all new trade entries for the remainder of that day
2. WHILE daily equity drawdown is below 5% of day-start balance, THE EA SHALL allow new trade entries provided other conditions are met
3. THE EA SHALL calculate daily drawdown as (day_start_balance - current_equity) / day_start_balance × 100%
4. IF the daily drawdown limit is breached, THE EA SHALL log the event and increment a diagnostic counter
5. THE EA SHALL reset daily drawdown tracking at the start of each new calendar day

### Requirement 2: Total Drawdown Safety

**User Story:** As a trader, I want the EA to enforce a hard 10% total drawdown limit from the initial balance, so that I don't exceed prop firm maximum drawdown constraints.

#### Acceptance Criteria

1. WHEN total equity drawdown approaches 8% of initial balance THEN THE EA SHALL reduce maximum allowed risk to 50% of configured amount (halve lot size)
2. WHEN total equity drawdown reaches 9% of initial balance THEN THE EA SHALL stop all new trade entries
3. THE EA SHALL calculate total drawdown as (initial_balance - current_equity) / initial_balance × 100%
4. IF total drawdown exceeds 10%, THE EA SHALL log a critical warning and cease trading operations
5. THE EA SHALL persist initial balance across restarts until manually reset

### Requirement 3: Trade Entry Validation

**User Story:** As a trader, I want the EA to validate all entry conditions before opening a position, so that only high-probability setups are traded.

#### Acceptance Criteria

1. WHEN a knee breakout setup is armed THEN THE EA SHALL verify that ADX(14) ≥ 20 before allowing new entries
2. WHEN a buy knee setup is detected THEN THE EA SHALL verify that the setup meets: minimum 2 green bars before knee, knee is bearish, and last green bar body ≥ 60% of range
3. WHEN a sell knee setup is detected THEN THE EA SHALL verify that the setup meets: minimum 3 red bars before knee, knee is bullish, and last red bar body ≥ 70% of range (stricter than buy)
4. WHEN a setup trigger is crossed (Ask ≥ trigger for buy, Bid ≤ trigger for sell) THEN THE EA SHALL verify that spread ≤ 50 points before entry
5. IF any entry validation fails, THE EA SHALL log the rejection reason and maintain the armed setup for retry

### Requirement 4: Position Sizing and Risk Management

**User Story:** As a trader, I want the EA to calculate position size based on risk percentage and stop distance, so that each trade risks exactly 0.7% of account balance.

#### Acceptance Criteria

1. WHEN a trade is opened, THE EA SHALL calculate lot size such that loss if stopped = risk_percent × account_balance × growth_factor
2. WHERE growth_factor is account_balance / initial_balance (compound growth) AND capped at 2× the initial risk percentage
3. WHEN lot size is calculated, THE EA SHALL apply hard constraints: 0.05 ≤ lot ≤ 0.08 (prop firm limit)
4. WHERE broker volume step constraints apply, THE EA SHALL round lot to nearest valid step
5. IF calculated lot is below minimum (0.05) after rounding, THE EA SHALL reject the trade (return 0) rather than force a smaller position

### Requirement 5: Stop Loss and Take Profit Calculation

**User Story:** As a trader, I want the EA to calculate stop loss and take profit from actual fill price, not requested trigger price, so that risk/reward targets are accurate.

#### Acceptance Criteria

1. WHEN a position is filled, THE EA SHALL recalculate take profit as: actual_fill_price + RR × (actual_fill_price - stop_loss)
2. WHERE RR is configured as 2.0 for fixed take-profit
3. WHEN stop loss is set, THE EA SHALL ensure distance from entry satisfies broker minimum stops level (SYMBOL_TRADE_STOPS_LEVEL)
4. FOR BUY trades, THE EA SHALL ensure: entry_price > stop_loss AND take_profit > entry_price
5. FOR SELL trades, THE EA SHALL ensure: stop_loss > entry_price AND entry_price > take_profit

### Requirement 6: Hybrid Exit Management

**User Story:** As a trader, I want the EA to manage exits using a hybrid strategy combining fixed TP and trailing stop, so that I capture profits on winners while protecting against reversals.

#### Acceptance Criteria

1. WHEN price reaches +1R profit from entry, THE EA SHALL move stop loss to entry price (break-even at 1R)
2. WHEN break-even is applied, THE EA SHALL NOT modify the stop loss on subsequent checks (idempotent operation)
3. WHILE price moves in profit direction beyond +1R, THE EA SHALL trail stop loss behind price at 6× ATR distance
4. WHERE trailing stop would move closer to price (tighter), THE EA SHALL apply the new stop loss
5. WHERE trailing stop would move away from price (looser), THE EA SHALL NOT modify the stop loss
6. WHEN price hits fixed TP at 2.0× risk, THE EA SHALL allow MT5 auto-close via stop order
7. FOR BUY positions, THE EA SHALL ensure trailing stop is never above current price minus minimum stop distance
8. FOR SELL positions, THE EA SHALL ensure trailing stop is never below current price plus minimum stop distance

### Requirement 7: Setup Lifecycle Management

**User Story:** As a trader, I want the EA to manage setup validity to prevent stale setups from being traded, so that I avoid entries in changed market conditions.

#### Acceptance Criteria

1. WHEN a knee pattern is detected and setup is armed, THE EA SHALL set validity window to 5 bars
2. WHILE a setup is armed, THE EA SHALL decrement validity counter by 1 at each new bar
3. WHEN validity counter reaches 0, THE EA SHALL disarm the setup and prevent entry
4. WHERE setup trigger is crossed before expiry, THE EA SHALL disarm the setup immediately after entry
5. WHEN new bar is detected and no position exists, THE EA SHALL scan for new setups (buy first, then sell)

### Requirement 8: Entry Time Filtering

**User Story:** As a trader, I want the EA to skip entries on Thursday and Friday based on historical failure data, so that I avoid low-probability trading days.

#### Acceptance Criteria

1. WHEN current day-of-week is Thursday, THE EA SHALL reject all new trade entries for the remainder of the day
2. WHEN current day-of-week is Friday, THE EA SHALL reject all new trade entries for the remainder of the day
3. WHERE an armed setup exists on Thursday or Friday, THE EA SHALL allow the setup to expire naturally but not trigger new entries
4. THE EA SHALL check day-of-week at each new bar and update rejection state accordingly
5. IF a valid setup exists on Monday–Wednesday, THE EA SHALL allow entry when trigger is crossed

### Requirement 9: Max Trades Per Day Limit

**User Story:** As a trader, I want the EA to limit entries to 4 per calendar day, so that I avoid over-trading and maintain discipline.

#### Acceptance Criteria

1. WHEN daily trade count reaches 4 entries, THE EA SHALL reject all new trade entries for the remainder of the day
2. WHERE daily trade count is below 4, THE EA SHALL allow new entries if other conditions are met
3. WHEN a trade is successfully opened, THE EA SHALL increment daily trade count by 1
4. THE EA SHALL reset daily trade count to 0 at the start of each new calendar day
5. THE EA SHALL track daily trade count independently from daily P&L calculations

### Requirement 10: ADX-Based Regime Detection

**User Story:** As a trader, I want the EA to detect trending vs ranging markets using ADX(14), so that I avoid entries during low-momentum chop.

#### Acceptance Criteria

1. WHEN ADX(14) value is read, THE EA SHALL classify market as trending if ADX ≥ 20
2. WHEN ADX(14) value is below 20, THE EA SHALL classify market as ranging
3. IF market is classified as ranging, THE EA SHALL block new knee breakout setups
4. WHEN indicator read fails (returns 0 or invalid handle), THE EA SHALL allow entry (fail-open) to avoid blocking trades on indicator errors
5. THE EA SHALL cache ADX value per bar to avoid recalculating on every tick

### Requirement 11: Indicator Management

**User Story:** As a trader, I want the EA to calculate and cache key indicators (EMA 21/50, ATR 14, ADX 14), so that entry decisions are based on accurate technical data.

#### Acceptance Criteria

1. THE EA SHALL calculate EMA(21) and EMA(50) values from M5 close prices
2. THE EA SHALL calculate ATR(14) value from M5 high-low-close data
3. THE EA SHALL calculate ADX(14) value from M5 price movement data
4. WHERE indicator calculations are needed, THE EA SHALL use cached values from current bar (not recalculate per tick)
5. IF any indicator handle is invalid or returns 0, THE EA SHALL skip setup scanning (fail-closed for entries)

### Requirement 12: EMA Trend Filter

**User Story:** As a trader, I want the EA to verify EMA alignment before entering trades, so that I only trade in the direction of the short-term trend.

#### Acceptance Criteria

1. FOR buy knee setups, THE EA SHALL verify that EMA(21) > EMA(50) AND knee close > EMA(21)
2. FOR sell knee setups, THE EA SHALL verify that EMA(21) < EMA(50) AND knee close < EMA(21)
3. WHEN EMA alignment is not satisfied, THE EA SHALL reject the knee pattern even if candle structure is valid
4. WHERE multiple indicator conditions must be met, THE EA SHALL check all conditions before arming setup
5. THE EA SHALL cache EMA values per bar for performance optimization

### Requirement 13: Spread Validation

**User Story:** As a trader, I want the EA to check spread before entry to avoid high-cost trades, so that I maintain consistent risk/reward ratios.

#### Acceptance Criteria

1. WHEN a trade is triggered, THE EA SHALL verify that current spread ≤ 50 points
2. IF spread exceeds 50 points, THE EA SHALL reject the entry and maintain the armed setup
3. THE EA SHALL re-check spread on each tick until trigger is crossed or setup expires
4. WHERE spread spike is detected, THE EA SHALL increment a diagnostic counter for tracking
5. Spread check is independent of other entry conditions (all must pass)

### Requirement 14: Daily Loss Limit in R Terms

**User Story:** As a trader, I want the EA to limit daily losses to 1.5R (1.5× average trade risk), so that I avoid catastrophic daily drawdowns.

#### Acceptance Criteria

1. WHEN running daily loss exceeds 1.5R, THE EA SHALL block all new trade entries for the remainder of the day
2. WHERE 1R is defined as (entry_price - stop_loss) for the current day's average trade, THE EA SHALL use a representative 1R value
3. THE EA SHALL calculate daily loss as sum of all losing trades for the current calendar day
4. WHERE daily loss in R terms exceeds 1.5, THE EA SHALL increment rejection counters
5. Daily loss limit resets at day boundary along with other daily counters

### Requirement 15: Position Management Constraints

**User Story:** As a trader, I want the EA to enforce single-position-only constraints, so that I avoid multiple overlapping trades that compound risk.

#### Acceptance Criteria

1. WHEN a position is already open, THE EA SHALL reject all new entry attempts until the position is closed
2. WHERE a setup is armed and new bar is detected, THE EA SHALL only scan for new setups if no position exists and no armed setup exists
3. WHEN position is closed (via TP, SL, or manual exit), THE EA SHALL reset position tracking flags
4. THE EA SHALL verify position ticket ownership using magic number (POSITION_MAGIC) before managing any position
5. Position count check is O(1) operation (single position maximum)

### Requirement 16: Break-Even Idempotency

**User Story:** As a trader, I want the EA to apply break-even stop only once per position, so that I avoid unnecessary modifications and potential slippage.

#### Acceptance Criteria

1. WHEN break-even condition is met (Bid ≥ entry + 1R for BUY, Ask ≤ entry - 1R for SELL), THE EA SHALL move SL to entry price
2. WHERE break-even has already been applied, THE EA SHALL NOT modify the stop loss on subsequent checks
3. THE EA SHALL track break-even state per position to ensure idempotent operation
4. Break-even offset is 0 points (exact entry price), no buffer allowed
5. Break-even does not modify take profit, only stop loss

### Requirement 17: Trailing Stop Monotonicity

**User Story:** As a trader, I want the EA to ensure trailing stop only moves in profit direction, so that I lock in gains and avoid moving stop loss against my position.

#### Acceptance Criteria

1. FOR BUY positions, WHEN price increases, THE EA SHALL calculate new trailing SL as Bid - (6 × ATR)
2. WHERE new trailing SL > current SL, THE EA SHALL apply the new stop loss
3. WHERE new trailing SL < current SL (would move against position), THE EA SHALL NOT modify the stop loss
4. FOR SELL positions, WHEN price decreases, THE EA SHALL calculate new trailing SL as Ask + (6 × ATR)
5. WHERE new trailing SL < current SL, THE EA SHALL apply the new stop loss
6. WHERE new trailing SL > current SL (would move against position), THE EA SHALL NOT modify the stop loss

### Requirement 18: Error Handling and Diagnostics

**User Story:** As a trader, I want the EA to log and track errors for debugging and performance analysis, so that I can identify and fix recurring issues.

#### Acceptance Criteria

1. WHEN spread exceeds maximum allowed, THE EA SHALL increment rejected_spread counter
2. WHEN regime filter blocks entry, THE EA SHALL increment rejected_regime counter
3. WHEN daily loss limit blocks entry, THE EA SHALL increment rejected_daily_limit counter
4. WHEN order execution fails, THE EA SHALL log retcode and categorize as transient (retry) or permanent (disarm)
5. THE EA SHALL maintain diagnostic counters accessible for post-trade analysis

### Requirement 19: Initialization and Configuration

**User Story:** As a trader, I want the EA to validate all configuration parameters on initialization, so that invalid settings don't cause unexpected behavior.

#### Acceptance Criteria

1. WHEN OnInit is called, THE EA SHALL verify that all indicator handles are valid (not INVALID_HANDLE)
2. WHERE indicator handles fail, THE EA SHALL return INIT_FAILED and prevent operation
3. THE EA SHALL initialize daily tracking variables (day_start_balance, trades_today, daily_pnl)
4. WHERE compound growth is enabled, THE EA SHALL capture initial balance from AccountBalance()
5. All configuration parameters must be within valid ranges (risk%: 0.1–2.0, ADX threshold: 15–30, etc.)

### Requirement 20: Prop Firm Challenge Compliance

**User Story:** As a trader, I want the EA to comply with Goat Funded Trader 5K 2-Step challenge rules, so that I can successfully pass the challenge.

#### Acceptance Criteria

1. THE EA SHALL enforce daily drawdown limit of 5% of day-start balance
2. THE EA SHALL enforce total drawdown limit of 10% of initial balance
3. WHERE lot sizing is applied, THE EA SHALL cap maximum lot at 0.08 (prop firm constraint)
4. THE EA SHALL trade exclusively on XAUUSD M5 timeframe
5. THE EA SHALL track entries per day to ensure no more than 4 trades are opened daily
