# Requirements Document

## Introduction

CK_XAU_ICT_ChoCh_V1 is a MetaTrader 5 Expert Advisor that implements an ICT-based multi-timeframe trading strategy on XAUUSD. The EA detects Change of Character (CHoCH) on H1 for directional bias, identifies Break of Structure (BOS) on M15 to confirm pullback completion, and enters trades on M5 at the Optimal Trade Entry (OTE) Fibonacci zone (0.62–0.786) with candlestick confirmation. The EA is designed for a Goat Funded Trader 5K 2-Step challenge account with strict drawdown rules and a $5,000 starting balance targeting $15,000 over 6 months.

## Glossary

- **EA**: The CK_XAU_ICT_ChoCh_V1 Expert Advisor running on MetaTrader 5
- **CHoCH (Change of Character)**: A structural shift where price breaks a significant swing high (bearish CHoCH) or swing low (bullish CHoCH) against the prevailing trend on H1
- **BOS (Break of Structure)**: A continuation break where price breaks a swing high (bullish BOS) or swing low (bearish BOS) in the direction of the established bias on M15
- **POI (Point of Interest)**: The last opposite-color candle before the impulse move that caused CHoCH on H1; functionally equivalent to an Order Block
- **Order_Block**: The last opposite-color candle body range before an impulse move; used on both H1 (as POI) and M15 (as entry zone)
- **OTE (Optimal Trade Entry)**: The Fibonacci retracement zone between 0.618 and 0.786 levels, measured from the M15 swing that caused BOS
- **Swing_High**: A price bar whose High is higher than the High of the preceding bar and the following bar (fractal-based detection)
- **Swing_Low**: A price bar whose Low is lower than the Low of the preceding bar and the following bar (fractal-based detection)
- **Confirmation_Candle**: A candlestick pattern on M5 (Bullish Engulfing, Bearish Engulfing, Doji with directional follow-through, or Pin Bar rejection) at the OTE zone that validates entry
- **RR (Risk-Reward Ratio)**: The ratio of potential profit to potential loss for a trade
- **BE (Break-Even)**: Moving the stop loss to entry price after TP1 is reached
- **Static_DD**: Maximum allowed drawdown measured from initial account balance ($5,000), not from equity high
- **Daily_Loss_Limit**: Maximum permitted loss in a single calendar day, calculated as 4% of balance at day start
- **Magic_Number**: Unique integer identifier assigned to trades opened by this EA

## Requirements

### Requirement 1: H1 CHoCH Detection

**User Story:** As a trader, I want the EA to detect Change of Character on the H1 timeframe, so that the EA establishes directional bias before seeking entries.

#### Acceptance Criteria

1. WHEN a new H1 bar completes, THE EA SHALL identify Swing_High and Swing_Low points using a minimum of 3 bars on each side (left and right) for fractal confirmation.
2. WHEN price closes below the most recent significant Swing_Low on H1 while the prior trend was bullish, THE EA SHALL classify the event as a Bearish CHoCH.
3. WHEN price closes above the most recent significant Swing_High on H1 while the prior trend was bearish, THE EA SHALL classify the event as a Bullish CHoCH.
4. WHEN a Bullish CHoCH is detected, THE EA SHALL mark the last bearish candle before the bullish impulse that broke the Swing_High as the H1 POI zone (Open to Low of that candle).
5. WHEN a Bearish CHoCH is detected, THE EA SHALL mark the last bullish candle before the bearish impulse that broke the Swing_Low as the H1 POI zone (Open to High of that candle).
6. THE EA SHALL maintain only one active CHoCH bias direction at a time, replacing the previous bias when a new CHoCH is detected.
7. WHEN a CHoCH is detected, THE EA SHALL log the direction, timestamp, swing level broken, and POI zone boundaries.

### Requirement 2: M15 Break of Structure Confirmation

**User Story:** As a trader, I want the EA to detect BOS on M15 in the direction of the H1 bias, so that the pullback completion is confirmed before entry.

#### Acceptance Criteria

1. WHILE an H1 Bullish CHoCH bias is active AND price has retraced into or near the H1 POI zone, WHEN price closes above the most recent M15 Swing_High, THE EA SHALL classify the event as a Bullish BOS.
2. WHILE an H1 Bearish CHoCH bias is active AND price has retraced into or near the H1 POI zone, WHEN price closes below the most recent M15 Swing_Low, THE EA SHALL classify the event as a Bearish BOS.
3. WHEN a Bullish BOS is detected on M15, THE EA SHALL mark the last bearish candle before the bullish impulse that broke the Swing_High as the M15 Order_Block (body range: Open to Close of that candle).
4. WHEN a Bearish BOS is detected on M15, THE EA SHALL mark the last bullish candle before the bearish impulse that broke the Swing_Low as the M15 Order_Block (body range: Open to Close of that candle).
5. THE EA SHALL use M15 Swing_High and Swing_Low detection with a minimum of 2 bars on each side for fractal confirmation.
6. THE EA SHALL invalidate the M15 BOS signal if a new opposing CHoCH occurs on H1 before entry is triggered.
7. WHEN a BOS is confirmed, THE EA SHALL log the BOS direction, M15 Order_Block boundaries, and the swing points used.

### Requirement 3: Fibonacci OTE Zone Calculation

**User Story:** As a trader, I want the EA to calculate Fibonacci retracement levels from the M15 BOS swing, so that the optimal trade entry zone is precisely defined.

#### Acceptance Criteria

1. WHEN a Bullish BOS is confirmed on M15, THE EA SHALL draw Fibonacci retracement from the High to the Low of the swing move that caused the BOS (retracement measured downward from the high).
2. WHEN a Bearish BOS is confirmed on M15, THE EA SHALL draw Fibonacci retracement from the Low to the High of the swing move that caused the BOS (retracement measured upward from the low).
3. THE EA SHALL calculate and store the 0.618, 0.705, and 0.786 Fibonacci retracement levels as the OTE zone boundaries.
4. THE EA SHALL define the valid entry zone as the price range between the 0.618 level and the 0.786 level (inclusive).
5. IF the OTE zone width is less than 2 dollars (200 points), THEN THE EA SHALL reject the setup and log the reason as insufficient zone width.
6. IF the OTE zone width exceeds 15 dollars (1500 points), THEN THE EA SHALL reject the setup and log the reason as excessive zone width.

### Requirement 4: M5 Confirmation Candle Entry

**User Story:** As a trader, I want the EA to enter trades only when a valid confirmation candle forms at the OTE zone on M5, so that entries have price action validation.

#### Acceptance Criteria

1. WHILE price is within the OTE zone (between 0.618 and 0.786 Fibonacci levels) AND the M15 Order_Block zone is active, WHEN a Bearish Engulfing pattern completes on M5 AND the bias is Bearish, THE EA SHALL generate a SELL entry signal.
2. WHILE price is within the OTE zone AND the M15 Order_Block zone is active, WHEN a Bullish Engulfing pattern completes on M5 AND the bias is Bullish, THE EA SHALL generate a BUY entry signal.
3. WHILE price is within the OTE zone AND the M15 Order_Block zone is active, WHEN a Doji forms on M5 AND the next M5 candle closes in the bias direction, THE EA SHALL generate an entry signal in the bias direction.
4. WHILE price is within the OTE zone AND the M15 Order_Block zone is active, WHEN a Pin Bar with a rejection wick of at least 60% of total candle range forms on M5 in the bias direction, THE EA SHALL generate an entry signal in the bias direction.
5. THE EA SHALL define a Bearish Engulfing pattern as: the current candle body fully contains the previous candle body AND the current candle closes below the previous candle open AND the current candle is bearish.
6. THE EA SHALL define a Bullish Engulfing pattern as: the current candle body fully contains the previous candle body AND the current candle closes above the previous candle open AND the current candle is bullish.
7. THE EA SHALL define a Doji as: a candle whose body size is less than 20% of the total candle range (High minus Low).
8. WHEN an entry signal is generated, THE EA SHALL place the trade at the close price of the confirmation candle (market order on next tick after candle close).

### Requirement 5: Stop Loss Placement

**User Story:** As a trader, I want stop loss placed beyond the M15 Order Block with a buffer, so that normal price wicks do not trigger premature exits.

#### Acceptance Criteria

1. WHEN a BUY trade is entered, THE EA SHALL set the stop loss at the Low of the M15 Order_Block minus 1 dollar (100 points) buffer.
2. WHEN a SELL trade is entered, THE EA SHALL set the stop loss at the High of the M15 Order_Block plus 1 dollar (100 points) buffer.
3. IF the calculated stop loss distance is less than 5 dollars (500 points) from entry price, THEN THE EA SHALL set the minimum stop loss distance to 5 dollars (500 points).
4. IF the calculated stop loss distance exceeds 15 dollars (1500 points) from entry price, THEN THE EA SHALL reject the trade and log the reason as excessive stop loss distance.
5. THE EA SHALL calculate the stop loss price before sending the order and include the stop loss in the initial order request.

### Requirement 6: Take Profit and Partial Close

**User Story:** As a trader, I want two take-profit targets with partial closure at TP1, so that profits are secured while allowing winners to run.

#### Acceptance Criteria

1. WHEN a trade is opened, THE EA SHALL set TP1 at 2 times the risk distance (1:2 RR) from the entry price.
2. WHEN a trade is opened, THE EA SHALL set TP2 at 3 times the risk distance (1:3 RR) from the entry price.
3. WHEN price reaches TP1, THE EA SHALL close 50% of the position volume (rounded down to the nearest valid lot step).
4. WHEN TP1 is hit AND 50% of the position is closed, THE EA SHALL move the stop loss of the remaining position to the entry price (break-even).
5. WHEN price reaches TP2, THE EA SHALL close the remaining position entirely.
6. IF the remaining lot size after TP1 partial close is below the minimum lot size (0.01), THEN THE EA SHALL close the entire position at TP1.

### Requirement 7: Position Sizing and Lot Calculation

**User Story:** As a trader, I want risk-based position sizing capped at 0.08 lots, so that each trade risks exactly 1% of account balance within prop firm constraints.

#### Acceptance Criteria

1. THE EA SHALL calculate lot size using the formula: Lot = (Balance × 0.01) / (SL_distance_in_points × point_value_per_lot).
2. THE EA SHALL cap the maximum lot size at 0.08 regardless of calculated lot size.
3. THE EA SHALL set the minimum lot size to 0.01.
4. THE EA SHALL round the calculated lot size down to the nearest valid lot step for the XAUUSD symbol.
5. IF the calculated lot size is below 0.01, THEN THE EA SHALL reject the trade and log the reason as insufficient margin for minimum lot.
6. THE EA SHALL verify that the required margin for the calculated lot does not exceed 80% of free margin before placing the trade.
7. IF required margin exceeds 80% of free margin, THEN THE EA SHALL reject the trade and log the reason as insufficient margin.

### Requirement 8: Daily Loss Limit Protection

**User Story:** As a trader, I want the EA to stop trading when daily losses reach 4% of day-start balance, so that the prop firm daily drawdown rule is never violated.

#### Acceptance Criteria

1. WHEN a new trading day begins (00:00 server time), THE EA SHALL record the account balance as the Day_Start_Balance.
2. THE EA SHALL continuously track the total realized losses for the current trading day.
3. WHEN daily realized losses reach 4% of Day_Start_Balance, THE EA SHALL stop opening new trades for the remainder of that trading day.
4. WHEN daily realized losses reach 4% of Day_Start_Balance, THE EA SHALL log a warning message including the loss amount and the day-start balance.
5. WHEN a new trading day begins, THE EA SHALL reset the daily loss counter to zero and resume normal trading operations.

### Requirement 9: Static Drawdown Protection

**User Story:** As a trader, I want the EA to halt all trading if the account drawdown from initial balance reaches 13%, so that the prop firm overall drawdown rule is protected with a safety buffer.

#### Acceptance Criteria

1. THE EA SHALL store the initial account balance ($5,000) as a configurable input parameter.
2. THE EA SHALL calculate static drawdown as: (Initial_Balance - Current_Balance) / Initial_Balance × 100.
3. WHEN static drawdown reaches 13% (balance drops to $4,350 or below), THE EA SHALL close all open positions immediately.
4. WHEN static drawdown reaches 13%, THE EA SHALL disable all new trade entries until the EA is manually restarted or the parameter is reset.
5. THE EA SHALL check the static drawdown condition before opening any new trade and on every tick while positions are open.
6. WHEN static drawdown protection is triggered, THE EA SHALL log an alert with the current balance, loss amount, and drawdown percentage.

### Requirement 10: Trade Frequency Limits

**User Story:** As a trader, I want the EA to limit trading frequency, so that overtrading and excessive exposure are prevented.

#### Acceptance Criteria

1. THE EA SHALL allow a maximum of 3 trades per calendar day (configurable input parameter).
2. THE EA SHALL count a trade as taken when an order is successfully filled (not when a signal is generated).
3. WHEN the daily trade count reaches the maximum, THE EA SHALL stop generating new entry signals for the remainder of that trading day.
4. THE EA SHALL maintain only one open position at a time (no simultaneous positions).
5. IF a trade signal is generated while a position is already open, THEN THE EA SHALL discard the signal and log the rejection reason.
6. WHEN a new trading day begins, THE EA SHALL reset the daily trade counter to zero.

### Requirement 11: Minimum Hold Time

**User Story:** As a trader, I want the EA to enforce a minimum 2-minute hold time on all trades, so that prop firm minimum hold time rules are respected.

#### Acceptance Criteria

1. THE EA SHALL not close or modify any position within 2 minutes (120 seconds) of the position open time, except for stop loss being hit by the broker.
2. THE EA SHALL track the open time of each position using the order fill timestamp.
3. WHILE a position has been open for less than 120 seconds, THE EA SHALL suppress all partial close, break-even, and take-profit operations managed by the EA.
4. WHEN the 2-minute threshold has elapsed, THE EA SHALL resume normal trade management operations (TP1 partial close, BE move, TP2 close).

### Requirement 12: Spread Filter

**User Story:** As a trader, I want the EA to skip entries when the spread is excessively wide, so that slippage does not distort the risk-reward calculation.

#### Acceptance Criteria

1. WHEN an entry signal is generated, THE EA SHALL check the current spread in points.
2. IF the current spread exceeds 50 points at the moment of entry signal, THEN THE EA SHALL reject the trade and log the reason as excessive spread.
3. THE EA SHALL use a configurable input parameter for the maximum allowed spread (default: 50 points).

### Requirement 13: Magic Number and Trade Identification

**User Story:** As a trader, I want all EA trades tagged with a unique magic number, so that this EA's trades are distinguishable from other EAs or manual trades.

#### Acceptance Criteria

1. THE EA SHALL assign a configurable Magic_Number (default: 20260801) to every order placed.
2. THE EA SHALL only manage (modify, close, or track) positions that carry the assigned Magic_Number.
3. THE EA SHALL ignore all positions on the account that do not carry the assigned Magic_Number.

### Requirement 14: Setup Invalidation and Timeout

**User Story:** As a trader, I want stale setups to be automatically invalidated, so that the EA does not enter trades on outdated market structure.

#### Acceptance Criteria

1. IF an M15 BOS signal has been active for more than 12 H1 bars (12 hours) without an M5 entry trigger, THEN THE EA SHALL invalidate the setup and clear all pending zone data.
2. IF a new CHoCH is detected on H1 that contradicts the current bias direction, THEN THE EA SHALL immediately invalidate all pending M15 BOS signals and OTE zones.
3. IF price moves beyond the M15 Order_Block zone without triggering an entry (price passes through OTE zone without confirmation candle), THEN THE EA SHALL invalidate the current setup.
4. WHEN a setup is invalidated, THE EA SHALL log the invalidation reason and timestamp.

### Requirement 15: Configurable Input Parameters

**User Story:** As a trader, I want all key strategy parameters exposed as configurable inputs, so that the EA can be optimized and adapted without code changes.

#### Acceptance Criteria

1. THE EA SHALL expose the following as input parameters with specified defaults: Risk_Percent (1.0), Max_Lot (0.08), RR_TP1 (2.0), RR_TP2 (3.0), Partial_Close_Percent (50), Max_Trades_Per_Day (3), Daily_Loss_Percent (4.0), Static_DD_Percent (13.0), Max_Spread_Points (50), Min_Hold_Seconds (120), SL_Buffer_Dollars (1.0), Min_SL_Dollars (5.0), Max_SL_Dollars (15.0), Initial_Balance (5000.0), Magic_Number (20260801).
2. THE EA SHALL expose the following structural detection parameters with defaults: H1_Swing_Bars (3), M15_Swing_Bars (2), Fib_Level_Low (0.618), Fib_Level_High (0.786), Min_OTE_Width_Dollars (2.0), Max_OTE_Width_Dollars (15.0), Setup_Timeout_H1_Bars (12).
3. THE EA SHALL expose an optional EMA 200 filter toggle: Use_EMA200_Filter (false), EMA200_Period (200), EMA200_Timeframe (H1).
4. THE EA SHALL validate all input parameters on initialization and halt with an error message if any value is out of acceptable range.

### Requirement 16: Logging and Diagnostics

**User Story:** As a trader, I want comprehensive logging of all EA decisions, so that strategy performance can be analyzed and issues debugged.

#### Acceptance Criteria

1. THE EA SHALL log every CHoCH detection event with direction, price level, and timestamp.
2. THE EA SHALL log every BOS detection event with direction, Order_Block boundaries, and Fibonacci levels.
3. THE EA SHALL log every entry signal generated, including confirmation candle type, entry price, SL, TP1, TP2, and lot size.
4. THE EA SHALL log every trade rejection with the specific reason (spread, margin, daily limit, DD limit, setup invalid, lot too small, SL too wide).
5. THE EA SHALL log every trade management action (TP1 partial close, BE move, TP2 close, SL hit).
6. WHEN InpVerboseLogs is set to true, THE EA SHALL log intermediate structure detection details (swing points found, zone boundaries updated).
7. THE EA SHALL prefix all log messages with the EA name "ICT_ChoCh" and the Magic_Number for filtering.

### Requirement 17: Initialization and Validation

**User Story:** As a trader, I want the EA to validate its operating environment on startup, so that misconfiguration is caught before live trading begins.

#### Acceptance Criteria

1. WHEN the EA is initialized (OnInit), THE EA SHALL verify the chart symbol is XAUUSD and halt with an error if it is not.
2. WHEN the EA is initialized, THE EA SHALL verify the chart timeframe is M5 and halt with an error if it is not.
3. WHEN the EA is initialized, THE EA SHALL verify that the account leverage does not exceed 1:30 and log a warning if it does.
4. WHEN the EA is initialized, THE EA SHALL verify trade permissions are enabled (AutoTrading is on) and halt with an error if trading is disabled.
5. WHEN the EA is initialized, THE EA SHALL load historical H1 and M15 data sufficient for swing detection (minimum 200 bars on each timeframe) and halt with an error if data is unavailable.

### Requirement 18: No Prohibited Techniques

**User Story:** As a trader, I want the EA to avoid all prohibited trading techniques, so that prop firm rules are never violated.

#### Acceptance Criteria

1. THE EA SHALL not open opposing positions simultaneously (no hedging).
2. THE EA SHALL not increase lot size after a losing trade (no martingale).
3. THE EA SHALL not use grid-based entries or dollar-cost averaging.
4. THE EA SHALL maintain a maximum of one open position at any time.
5. THE EA SHALL not place pending orders (only market orders on confirmation candle close).
