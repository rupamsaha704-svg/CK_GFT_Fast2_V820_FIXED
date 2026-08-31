# Implementation Plan: XAUUSD Prop Firm EA (Hybrid V20 + Trailing)

## Overview

This implementation plan breaks down the XAUUSD M5 Knee Breakout Expert Advisor with hybrid exit strategy into manageable coding tasks. The EA must enforce strict prop firm constraints (5% daily DD, 10% total DD, 0.05-0.08 lot cap, 4 trades/day max) while implementing sophisticated entry logic based on knee breakout patterns and regime detection using ADX.

The implementation follows a modular approach: indicator management, risk management, signal generation, regime filtering, exit management, and trade execution, all coordinated through the main OnTick handler.

## Tasks

- [ ] 1. Initialize EA and Indicator Handles
  - [ ] 1.1 Create configuration structure with all input parameters
    - Define EAConfig struct with all 25+ configuration parameters
    - Include bounds validation for all numeric parameters
    - _Requirements: 19.5_
  
  - [ ] 1.2 Initialize indicator handles in OnInit
    - Create handles for ATR(14), EMA(21), EMA(50), ADX(14)
    - Validate all handles are not INVALID_HANDLE
    - Return INIT_FAILED if any handle creation fails
    - _Requirements: 19.1, 19.2, 11.5_
  
  - [ ] 1.3 Initialize global state variables
    - Set dayStart = 0 (no day yet)
    - Initialize tradesToday = 0, dailyPnL = 0
    - Capture initialBalance from AccountBalance()
    - Initialize diagnostic counters to 0
    - _Requirements: 19.3, 19.4_

- [ ] 2. Implement Indicator Management Component
  - [ ] 2.1 Create indicator cache structure
    - Define structure to cache ATR, EMA(21), EMA(50), ADX per bar
    - Include timestamp for cache validation
    - _Requirements: 11.4_
  
  - [ ] 2.2 Implement indicator update function
    - Copy ATR values from indicator handle
    - Copy EMA values from indicator handles
    - Copy ADX values from indicator handle
    - Update cache timestamp on successful copy
    - _Requirements: 11.1, 11.2, 11.3_
  
  - [ ] 2.3 Implement indicator access functions
    - GetATR(), GetEMA21(), GetEMA50(), GetADX()
    - Return cached values from current bar
    - Handle invalid handle case (fail-closed for ATR/EMA, fail-open for ADX)
    - _Requirements: 11.4, 10.4, 11.5_

- [ ] 3. Implement Risk Manager Component
  - [ ] 3.1 Create risk manager class with daily tracking
    - Track dayStartBalance, tradesToday, dailyPnL
    - Initialize at day boundary
    - _Requirements: 1.5, 9.4, 14.3_
  
  - [ ] 3.2 Implement daily drawdown check
    - Calculate: (dayStartBalance - currentEquity) / dayStartBalance × 100%
    - Return false if >= 5% threshold
    - Increment rejectedDailyLimit counter on rejection
    - _Requirements: 1.1, 1.2, 1.4, 1.5_
  
  - [ ] 3.3 Implement total drawdown check
    - Calculate: (initialBalance - currentEquity) / initialBalance × 100%
    - At 8%: reduce lot to 50%
    - At 9%: block all entries
    - At 10%: log critical warning and cease trading
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_
  
  - [ ] 3.4 Implement max trades per day check
    - Reject if tradesToday >= 4
    - Increment counter on successful entry
    - Reset at day boundary
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_
  
  - [ ] 3.5 Implement spread validation
    - Check SymbolInfoInteger(SYMBOL_SPREAD) <= 50
    - Reject and increment rejectedSpread counter if exceeded
    - _Requirements: 3.4, 13.1, 13.2, 13.3, 13.4, 13.5_
  
  - [ ] 3.6 Implement day-of-week filter
    - Reject Thursday and Friday entries
    - Use TimeDayOfWeek() to check day
    - Allow setups to expire naturally on blocked days
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_
  
  - [ ] 3.7 Implement daily loss limit in R terms
    - Calculate 1R as average trade risk for the day
    - Block if daily loss exceeds 1.5R
    - Track losing trades for the day
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5_
  
  - [ ] 3.8 Implement lot size calculation with compound growth
    - Calculate: riskMoney = balance × (riskPercent × growthFactor / 100)
    - Apply growthFactor = min(balance / initialBalance, 2.0)
    - Use OrderCalcProfit to get lossPerLot
    - Calculate: rawLots = riskMoney / lossPerLot
    - Apply volume step rounding
    - Enforce caps: 0.05 <= lots <= 0.08
    - Reject if below minimum after rounding
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_
  
  - [ ] 3.9 Implement master guard function
    - Combine all checks: spread, daily loss, max trades, position count, weekday
    - Return false if any guard fails
    - Log rejection reason and increment counter
    - _Requirements: 15.1, 15.2, 15.5, 18.1, 18.2, 18.3_

- [ ] 4. Implement Signal Generator Component
  - [ ] 4.1 Create setup state structure
    - Track direction (1=buy, -1=sell, 0=none)
    - Store triggerPrice, pendingSL, barsRemaining
    - Track setupTime and lastTradedSetup
    - _Requirements: 7.1, 7.4_
  
  - [ ] 4.2 Implement buy knee detection algorithm
    - Verify minimum 2 consecutive green bars before current bar
    - Verify current bar is bearish (the "knee")
    - Verify last green bar body >= 60% of range
    - Verify EMA(21) > EMA(50) AND knee close > EMA(21)
    - Calculate trigger = knee.high, SL = knee.low - buffer
    - Enforce trigger > SL
    - Set up state for arming
    - _Requirements: 3.2, 12.1, 12.2_
  
  - [ ] 4.3 Implement sell knee detection algorithm (stricter)
    - Verify minimum 3 consecutive red bars before current bar
    - Verify current bar is bullish (the "knee")
    - Verify last red bar body >= 70% of range (STRICTER than buy)
    - Verify EMA(21) < EMA(50) AND knee close < EMA(21)
    - Calculate trigger = knee.low, SL = knee.high + buffer
    - Enforce SL > trigger
    - Set up state for arming
    - _Requirements: 3.3, 12.1, 12.2_
  
  - [ ] 4.4 Implement setup arming functions
    - ArmBuySetup() and ArmSellSetup()
    - Set direction, triggerPrice, pendingSL, barsRemaining
    - Reset lastTradedSetup timestamp
    - _Requirements: 7.1, 7.4_
  
  - [ ] 4.5 Implement setup expiry management
    - Decrement barsRemaining at each new bar
    - Disarm if barsRemaining <= 0
    - _Requirements: 7.2, 7.3, 7.5_
  
  - [ ] 4.6 Implement trigger checking
    - Check Ask >= triggerPrice for buy setups
    - Check Bid <= triggerPrice for sell setups
    - Combine with IsAllowedToTrade() check
    - _Requirements: 3.5, 15.1_

- [ ] 5. Implement Regime Filter Component
  - [ ] 5.1 Implement regime classification
    - Read ADX(14) from cache
    - Return true (trending) if ADX >= threshold
    - Return false (ranging) if ADX < threshold
    - Fail-open on indicator error (return true)
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_
  
  - [ ] 5.2 Implement regime check in entry flow
    - Call RegimeFilter() before scanning for setups
    - Skip new setup if market is ranging
    - Increment rejectedRegime counter on rejection
    - _Requirements: 10.3, 3.1_

- [ ] 6. Implement Exit Manager Component
  - [ ] 6.1 Implement break-even management
    - Calculate initialRisk = |entry - currentSL|
    - For BUY: if Bid >= entry + initialRisk, move SL to entry
    - For SELL: if Ask <= entry - initialRisk, move SL to entry
    - Track beApplied flag to ensure idempotency
    - Respect broker minimum stop distance
    - _Requirements: 6.1, 6.2, 16.1, 16.2, 16.3, 16.4, 16.5_
  
  - [ ] 6.2 Implement trailing stop management
    - Only activate after +1R profit
    - For BUY: newSL = Bid - (trailATR × ATR)
    - For SELL: newSL = Ask + (trailATR × ATR)
    - Only apply if newSL moves in profit direction
    - Respect broker minimum stop distance
    - Store trailing SL in state for next comparison
    - _Requirements: 6.3, 6.4, 6.5, 17.1, 17.2, 17.3, 17.4, 17.5, 17.6_
  
  - [ ] 6.3 Implement fixed TP verification
    - Verify TP was calculated from actual fill price
    - TP = fill + RR × (fill - SL) for BUY
    - TP = fill - RR × (SL - fill) for SELL
    - RR = 2.0 as configured
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_
  
  - [ ] 6.4 Implement position management structure
    - Track positionTicket, entryPrice, beApplied flag
    - Validate ownership via POSITION_MAGIC
    - _Requirements: 15.4, 15.5_

- [ ] 7. Implement Trade Executor Component
  - [ ] 7.1 Implement position opening functions
    - OpenBuy(lots, sl, tp) and OpenSell(lots, sl, tp)
    - Use CTrade class with proper settings
    - Validate fill with PositionSelectByTicket()
    - Record actual fill price
    - _Requirements: 18.4_
  
  - [ ] 7.2 Implement TP recalculation from fill
    - Recalculate TP after fill using actual fill price
    - TP = actualFill + RR × (actualFill - SL)
    - Ensure TP distance satisfies broker minimums
    - Modify position to update TP
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_
  
  - [ ] 7.3 Implement position modification function
    - ModifyPosition(ticket, newSL, newTP)
    - Validate new SL distance >= SYMBOL_TRADE_STOPS_LEVEL
    - Apply with trade.Modify()
    - Log failures for diagnostics
    - _Requirements: 5.3_
  
  - [ ] 7.4 Implement position count and ownership check
    - CountPositions(): count positions with matching magic number
    - GetPositionTicket(): return ticket if single position exists
    - HasPosition(): boolean check
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5_
  
  - [ ] 7.5 Implement position closing function
    - ClosePosition(ticket)
    - Use trade.Close() with proper settings
    - Update daily P&L tracking
    - _Requirements: 15.3_

- [ ] 8. Implement Main Entry Logic (OnTick Handler)
  - [ ] 8.1 Implement daily boundary detection and reset
    - Check if new day (time changes to new D1 bar)
    - Call ResetDaily() to reset daily counters
    - Update dayStart timestamp
    - _Requirements: 1.5, 9.4, 14.3_
  
  - [ ] 8.2 Implement exit management loop
    - For each open position with matching magic
    - Call ManageBreakEven()
    - Call ManageTrailingStop()
    - Verify fixed TP calculation
    - _Requirements: 6.1, 6.2, 6.3, 6.4_
  
  - [ ] 8.3 Implement new bar detection and setup expiry
    - Check IsNewBar() to detect new candle
    - Expire old setups by decrementing barsRemaining
    - Disarm if validity window expired
    - _Requirements: 7.2, 7.3, 7.5_
  
  - [ ] 8.4 Implement setup scanning (new bar, no position)
    - Check regime filter (ADX >= threshold)
    - Try ScanBuyKnee() first
    - If no buy, try ScanSellKnee()
    - Arm valid setup if found
    - _Requirements: 3.1, 10.1, 10.3_
  
  - [ ] 8.5 Implement entry trigger checking
    - Check if setup is armed (direction != 0)
    - Check if no position exists
    - Verify IsAllowedToTrade() passes
    - For BUY: if Ask >= trigger, attempt OpenBuy()
    - For SELL: if Bid <= trigger, attempt OpenSell()
    - Disarm setup after successful entry
    - _Requirements: 3.4, 3.5, 15.1_

- [ ] 9. Implement Error Handling and Diagnostics
  - [ ] 9.1 Implement spread rejection handler
    - Increment rejectedSpread counter
    - Log rejection reason
    - Keep setup armed for retry
    - _Requirements: 18.1_
  
  - [ ] 9.2 Implement regime filter rejection handler
    - Increment rejectedRegime counter
    - Log rejection reason
    - Skip new setup entry
    - _Requirements: 18.2_
  
  - [ ] 9.3 Implement daily limit rejection handler
    - Increment rejectedDailyLimit counter
    - Log rejection reason
    - Prevent entry while limit active
    - _Requirements: 18.3_
  
  - [ ] 9.4 Implement order execution error handler
    - Check trade.ResultRetcode() for category
    - Transient (requote, timeout): keep setup armed
    - Permanent (invalid stops, no money): disarm setup
    - Log retcode for debugging
    - _Requirements: 18.4_
  
  - [ ] 9.5 Implement indicator failure handler
    - For ATR/EMA: skip setup scanning (fail-closed)
    - For ADX: allow entry (fail-open)
    - Log error with indicator name
    - _Requirements: 11.5, 10.4_

- [ ] 10. Implement Configuration Validation
  - [ ] 10.1 Validate input parameters in OnInit
    - riskPercent: [0.1, 2.0]
    - adxThreshold: [15, 30]
    - trailATR: >= 3.0 (for gold volatility)
    - maxLot: <= 0.08 (prop firm cap)
    - kneeMinRunBuy: >= 2
    - kneeMinRunSell: >= kneeMinRunBuy
    - _Requirements: 19.5_
  
  - [ ] 10.2 Validate indicator handle creation
    - Check all handles != INVALID_HANDLE
    - Return INIT_FAILED on any failure
    - _Requirements: 19.1, 19.2_

- [ ] 11. Implement Testing Tasks
  - [ ]* 11.1 Write unit tests for indicator caching
    - Verify cache returns same value for multiple calls in same bar
    - Verify cache invalidates on new bar
    - Verify fail-closed for ATR/EMA, fail-open for ADX
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_
  
  - [ ]* 11.2 Write property test for lot size calculation
    - **Property 9: Risk Calculation**
    - **Validates: Requirements 4.1, 4.2**
    - Generate random balance/SL scenarios, verify lot × SL ≈ riskMoney
    - Verify lot is within [0.05, 0.08]
    - Verify compound growth capped at 2×
  
  - [ ]* 11.3 Write unit tests for daily drawdown checks
    - Test daily drawdown = 5% blocks new entries
    - Test daily drawdown < 5% allows entries
    - Test daily loss reset at day boundary
    - _Requirements: 1.1, 1.2, 1.4, 1.5_
  
  - [ ]* 11.4 Write property test for trailing stop monotonicity
    - **Property 13: SL Monotonicity (BUY)**
    - **Validates: Requirements 6.3, 6.4, 6.5, 17.1, 17.2, 17.3**
    - For BUY: trailing SL never decreases
    - Generate random price sequences, verify SL never moves backward
  
  - [ ]* 11.5 Write property test for trailing stop monotonicity (SELL)
    - **Property 14: SL Monotonicity (SELL)**
    - **Validates: Requirements 6.3, 6.5, 17.4, 17.5, 17.6**
    - For SELL: trailing SL never increases
    - Generate random price sequences, verify SL never moves away from price
  
  - [ ]* 11.6 Write unit tests for break-even idempotency
    - **Property 5: BE Idempotency**
    - **Validates: Requirements 6.2, 16.2, 16.3, 16.4, 16.5**
    - Verify SL only moves to entry once
    - Subsequent calls produce no change
  
  - [ ]* 11.7 Write property test for max trades per day
    - **Property 19: Max Trades Per Day**
    - **Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.5, 20.5**
    - Generate random day boundaries, verify trades <= 4
  
  - [ ]* 11.8 Write property test for daily loss limit
    - **Property 2: Daily Loss Limit**
    - **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5**
    - Generate random daily loss scenarios, verify rejection at 5%
  
  - [ ]* 11.9 Write property test for total drawdown safety
    - **Property 1: Drawdown Safety**
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5**
    - Generate random equity paths, verify DD < 10%
  
  - [ ]* 11.10 Write unit tests for knee pattern detection
    - Test buy knee: 2+ green bars → red knee → trigger
    - Test sell knee: 3+ red bars → green knee (STRICTER)
    - Test entry strength filters (60% buy, 70% sell)
    - Test EMA trend alignment
    - _Requirements: 3.2, 3.3, 12.1, 12.2_
  
  - [ ]* 11.11 Write property test for setup validity
    - **Property 6: Setup Validity**
    - **Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5**
    - Generate random setup arming, verify expiry after 5 bars
  
  - [ ]* 11.12 Write unit tests for spread validation
    - Test spread <= 50 allows entry
    - Test spread > 50 blocks entry
    - Test rejected_spread counter increments
    - _Requirements: 3.4, 13.1, 13.2, 13.3, 13.4, 13.5_
  
  - [ ]* 11.13 Write unit tests for regime filter
    - Test ADX >= 20 allows entry
    - Test ADX < 20 blocks entry
    - Test fail-open on ADX failure
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_
  
  - [ ]* 11.14 Write unit tests for day-of-week filter
    - Test Monday-Wednesday allows entries
    - Test Thursday-Friday blocks entries
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_
  
  - [ ]* 11.15 Write property test for compound growth cap
    - **Property 10: Compound Growth Cap**
    - **Validates: Requirements 4.2**
    - Verify growthFactor never exceeds 2.0
  
  - [ ]* 11.16 Write property test for lot constraint
    - **Property 3: Lot Constraint**
    - **Validates: Requirements 4.3, 4.5, 20.3**
    - Verify all executed trades have lot in [0.05, 0.08]
  
  - [ ]* 11.17 Write property test for TP from fill
    - **Property 7: TP from Fill**
    - **Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5**
    - Verify TP = fill + RR × (fill - SL) for BUY
    - Verify TP = fill - RR × (SL - fill) for SELL
  
  - [ ]* 11.18 Write property test for single position constraint
    - **Property 21: Single Position Maximum**
    - **Validates: Requirements 15.1, 15.2, 15.5**
    - Verify at most one position exists at any time
  
  - [ ]* 11.19 Write unit tests for break-even trigger
    - **Property 15: BE Activation**
    - **Validates: Requirements 6.1, 16.1**
    - Test BUY: SL moves to entry when Bid >= entry + 1R
    - Test SELL: SL moves to entry when Ask <= entry - 1R
  
  - [ ]* 11.20 Write integration tests for full entry flow
    - Backtest knee breakout pattern detection
    - Verify all guards are applied in correct order
    - Verify proper setup arming and triggering
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 7.1, 7.2, 7.3, 7.4, 7.5, 8.1, 8.2, 8.3, 8.4, 8.5_
  
  - [ ]* 11.21 Write integration tests for hybrid exit flow
    - Verify break-even applies at +1R
    - Verify trailing activates after +1R
    - Verify trailing never moves backward
    - Verify fixed TP calculation from fill
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 16.1, 16.2, 16.3, 16.4, 16.5, 17.1, 17.2, 17.3, 17.4, 17.5, 17.6_
  
  - [ ]* 11.22 Write end-to-end prop firm compliance test
    - Verify daily DD never exceeds 5%
    - Verify total DD never exceeds 10%
    - Verify lot never exceeds 0.08
    - Verify max 4 trades per day
    - Verify XAUUSD M5 only
    - _Requirements: 20.1, 20.2, 20.3, 20.4, 20.5_

- [ ] 12. Final Checkpoint - Ensure all tests pass
  - Ensure all unit tests pass
  - Ensure all property-based tests pass (if implemented)
  - Verify integration tests pass on XAUUSD M5 historical data
  - Ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property-based tests validate universal correctness properties
- Unit tests validate specific examples and edge cases

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3"] },
    { "id": 1, "tasks": ["2.1", "2.2", "2.3"] },
    { "id": 2, "tasks": ["3.1", "3.2", "3.3", "3.4"] },
    { "id": 3, "tasks": ["3.5", "3.6", "3.7", "3.8", "3.9"] },
    { "id": 4, "tasks": ["4.1", "4.2", "4.3", "4.4", "4.5", "4.6"] },
    { "id": 5, "tasks": ["5.1", "5.2", "6.1", "6.2", "6.3", "6.4"] },
    { "id": 6, "tasks": ["7.1", "7.2", "7.3", "7.4", "7.5"] },
    { "id": 7, "tasks": ["8.1", "8.2", "8.3", "8.4", "8.5"] },
    { "id": 8, "tasks": ["9.1", "9.2", "9.3", "9.4", "9.5", "10.1", "10.2"] },
    { "id": 9, "tasks": ["11.1", "11.2", "11.3", "11.4", "11.5", "11.6"] },
    { "id": 10, "tasks": ["11.7", "11.8", "11.9", "11.10", "11.11", "11.12"] },
    { "id": 11, "tasks": ["11.13", "11.14", "11.15", "11.16", "11.17", "11.18"] },
    { "id": 12, "tasks": ["11.19", "11.20", "11.21", "11.22", "12"] }
  ]
}
```