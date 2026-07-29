# Design Document: ICT CHoCH + Fibonacci EA

## Overview

CK_XAU_ICT_ChoCh_V1 is a multi-timeframe MetaTrader 5 Expert Advisor implementing an ICT-based structural trading strategy on XAUUSD. The EA runs on the M5 chart and reads H1/M15 data via `iBarShift` and `CopyRates` to detect CHoCH (directional bias), BOS (pullback confirmation), and OTE entries (Fibonacci zone + candlestick confirmation). All trade management (partial close, break-even, DD protection) is handled within a single-position, rule-based state machine.

---

## 1. High-Level Architecture

### 1.1 Component Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CK_XAU_ICT_ChoCh_V1.mq5                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐  │
│  │  H1 Analysis │    │ M15 Analysis │    │    M5 Execution      │  │
│  │              │    │              │    │                      │  │
│  │ • Swing Det. │───▶│ • Swing Det. │───▶│ • Confirm. Candle    │  │
│  │ • CHoCH Det. │    │ • BOS Det.   │    │ • Entry Logic        │  │
│  │ • POI Zone   │    │ • OB Zone    │    │ • Order Placement    │  │
│  │ • Bias Mgmt  │    │ • Fib Calc   │    │ • Trade Management   │  │
│  └──────────────┘    └──────────────┘    └──────────────────────┘  │
│         │                    │                      │               │
│         ▼                    ▼                      ▼               │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                     State Manager                            │   │
│  │  IDLE → H1_CHOCH → WAIT_POI → M15_BOS → WAIT_OTE → OPEN   │   │
│  └─────────────────────────────────────────────────────────────┘   │
│         │                    │                      │               │
│         ▼                    ▼                      ▼               │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                   Risk & Protection Layer                    │   │
│  │  • Position Sizing  • Daily Loss Limit  • Static DD Guard   │   │
│  │  • Spread Filter    • Max Trades/Day    • Min Hold Time     │   │
│  └─────────────────────────────────────────────────────────────┘   │
│         │                                                           │
│         ▼                                                           │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                     Logger / Diagnostics                     │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Multi-Timeframe Data Flow

```
H1 (via CopyRates, checked on new H1 bar)
  │
  │ Detects: Swing Highs/Lows, CHoCH events, POI zones
  │ Outputs: bias_direction, poi_zone{high, low}
  │
  ▼
M15 (via CopyRates, checked on new M15 bar)
  │
  │ Preconditions: H1 bias active, price near POI zone
  │ Detects: Swing Highs/Lows, BOS events, Order Blocks
  │ Outputs: bos_confirmed, ob_zone{high, low}, fib_levels{618, 705, 786}
  │
  ▼
M5 (native chart, checked on new M5 bar)
  │
  │ Preconditions: M15 BOS active, price in OTE zone
  │ Detects: Confirmation candles (Engulfing, Doji+Follow, Pin Bar)
  │ Outputs: entry_signal{direction, price, pattern_type}
  │
  ▼
Execution (on M5 candle close → next tick)
  │ Validates: Spread, Margin, Daily Limits, DD, Max Trades
  │ Places: Market order with SL + TP1/TP2
  │ Manages: Partial close, BE, TP2 close
```

### 1.3 Tick-Level Processing (`OnTick`)

```mql5
void OnTick()
{
   // 1. Risk checks (every tick while position open)
   CheckStaticDrawdown();
   
   // 2. Trade management (if position open)
   if(HasPosition())
      ManageOpenPosition();
   
   // 3. New bar processing only
   if(!IsNewM5Bar()) return;
   
   // 4. Day boundary reset
   CheckDayReset();
   
   // 5. H1 structure analysis (on H1 bar change)
   if(IsNewH1Bar())
      AnalyzeH1Structure();
   
   // 6. M15 structure analysis (on M15 bar change)
   if(IsNewM15Bar())
      AnalyzeM15Structure();
   
   // 7. Entry logic (every M5 bar, if setup is pending)
   if(g_state == WAITING_FOR_OTE_ENTRY)
      CheckM5Entry();
}
```

---

## 2. Low-Level Design

### 2.1 Swing Detection Algorithm

The swing detector is a fractal-based algorithm parameterized by `bars_required` (number of bars on each side that must have lower highs / higher lows).

```mql5
// Swing High: bar[i].High > bar[i-n].High for all n in [1..bars_required]
//         AND bar[i].High > bar[i+n].High for all n in [1..bars_required]
// Swing detected only on CONFIRMED bars (shift >= bars_required from current bar)

struct SwingPoint
{
   double   price;        // High for swing high, Low for swing low
   datetime time;         // Time of the swing bar
   int      bar_index;    // Bar index at detection time
   bool     is_high;      // true = swing high, false = swing low
};

bool IsSwingHigh(const MqlRates &bars[], int index, int bars_required)
{
   double pivot = bars[index].high;
   for(int i = 1; i <= bars_required; i++)
   {
      if(bars[index - i].high >= pivot) return false;  // left side
      if(bars[index + i].high >= pivot) return false;  // right side
   }
   return true;
}

bool IsSwingLow(const MqlRates &bars[], int index, int bars_required)
{
   double pivot = bars[index].low;
   for(int i = 1; i <= bars_required; i++)
   {
      if(bars[index - i].low <= pivot) return false;
      if(bars[index + i].low <= pivot) return false;
   }
   return true;
}
```

**Key Design Decisions:**
- H1 uses `bars_required = 3` (InpH1SwingBars) — stronger structure
- M15 uses `bars_required = 2` (InpM15SwingBars) — faster detection
- Only the two most recent swing highs/lows are tracked per timeframe
- Swing detection runs on completed bars only (shift ≥ bars_required)

### 2.2 CHoCH Detection Algorithm

CHoCH is detected when the prevailing trend structure is violated — price breaks a swing point against the established direction.

```mql5
enum ENUM_BIAS { BIAS_NONE = 0, BIAS_BULLISH = 1, BIAS_BEARISH = -1 };

struct CHoCH_Event
{
   ENUM_BIAS   direction;        // New bias direction after CHoCH
   double      swing_broken;     // Price level of broken swing
   datetime    time;             // Detection timestamp
   double      poi_high;         // POI zone upper boundary
   double      poi_low;          // POI zone lower boundary
   bool        valid;            // Currently active
};

// Detection logic (called on H1 bar close):
// 1. Determine prior trend from last two swing relationships:
//    - Bullish trend: Higher Highs AND Higher Lows
//    - Bearish trend: Lower Highs AND Lower Lows
// 2. Check for structural break:
//    - Bearish CHoCH: close < last significant swing low (in bullish trend)
//    - Bullish CHoCH: close > last significant swing high (in bearish trend)

void DetectCHoCH(const MqlRates &h1_bars[], SwingPoint &last_sh, SwingPoint &last_sl,
                 ENUM_BIAS prior_trend, CHoCH_Event &result)
{
   double close_price = h1_bars[0].close;  // Most recent completed H1 bar
   
   if(prior_trend == BIAS_BULLISH && close_price < last_sl.price)
   {
      result.direction = BIAS_BEARISH;
      result.swing_broken = last_sl.price;
      result.time = h1_bars[0].time;
      // POI = last bullish candle before bearish impulse
      FindPOI(h1_bars, last_sl.bar_index, true, result.poi_high, result.poi_low);
      result.valid = true;
   }
   else if(prior_trend == BIAS_BEARISH && close_price > last_sh.price)
   {
      result.direction = BIAS_BULLISH;
      result.swing_broken = last_sh.price;
      result.time = h1_bars[0].time;
      // POI = last bearish candle before bullish impulse
      FindPOI(h1_bars, last_sh.bar_index, false, result.poi_high, result.poi_low);
      result.valid = true;
   }
}
```

**POI Zone Identification:**
```mql5
// For Bullish CHoCH: find last bearish candle before the bullish impulse
//   POI high = Open of that candle, POI low = Low of that candle
// For Bearish CHoCH: find last bullish candle before the bearish impulse
//   POI high = High of that candle, POI low = Open of that candle

void FindPOI(const MqlRates &bars[], int impulse_start_idx, bool find_bullish_candle,
             double &poi_high, double &poi_low)
{
   for(int i = impulse_start_idx; i < ArraySize(bars); i++)
   {
      bool is_bullish = (bars[i].close > bars[i].open);
      if(find_bullish_candle && is_bullish)
      {
         // Bearish CHoCH: POI = last bullish candle (Open to High)
         poi_high = bars[i].high;
         poi_low  = bars[i].open;
         return;
      }
      else if(!find_bullish_candle && !is_bullish)
      {
         // Bullish CHoCH: POI = last bearish candle (Open to Low)
         poi_high = bars[i].open;
         poi_low  = bars[i].low;
         return;
      }
   }
}
```

### 2.3 BOS Detection on M15

BOS is confirmed only when three preconditions are met:
1. An active H1 CHoCH bias exists
2. Price has retraced into or touched the H1 POI zone
3. Price breaks the relevant M15 swing in the bias direction

```mql5
struct BOS_Event
{
   ENUM_BIAS   direction;        // BOS direction (matches H1 bias)
   double      ob_high;          // M15 Order Block upper boundary
   double      ob_low;           // M15 Order Block lower boundary
   double      swing_high_used;  // M15 swing high price
   double      swing_low_used;   // M15 swing low price
   datetime    time;             // Detection time
   datetime    expiry;           // Timeout (12 H1 bars from detection)
   bool        valid;
};

bool PriceInPOIZone(double current_low, double current_high,
                    double poi_high, double poi_low)
{
   // Price is "in or near" POI if any part of the candle touches the zone
   // or is within a small buffer (e.g., 50 points) of the zone
   double buffer = 50 * _Point;
   return (current_low <= poi_high + buffer && current_high >= poi_low - buffer);
}

void DetectBOS(const MqlRates &m15_bars[], SwingPoint &m15_sh, SwingPoint &m15_sl,
               ENUM_BIAS h1_bias, const CHoCH_Event &choch, BOS_Event &result)
{
   double close_price = m15_bars[0].close;
   
   // Check if price has retraced to POI zone (look at recent M15 bars)
   bool poi_tested = false;
   for(int i = 0; i < 12; i++)  // Check last 12 M15 bars (3 hours)
   {
      if(PriceInPOIZone(m15_bars[i].low, m15_bars[i].high, choch.poi_high, choch.poi_low))
      { poi_tested = true; break; }
   }
   if(!poi_tested) return;
   
   if(h1_bias == BIAS_BULLISH && close_price > m15_sh.price)
   {
      result.direction = BIAS_BULLISH;
      result.swing_high_used = m15_sh.price;
      result.swing_low_used = m15_sl.price;
      // Order Block = last bearish candle before bullish impulse
      FindM15OrderBlock(m15_bars, m15_sh.bar_index, false, result.ob_high, result.ob_low);
      result.time = m15_bars[0].time;
      result.expiry = result.time + 12 * PeriodSeconds(PERIOD_H1);
      result.valid = true;
   }
   else if(h1_bias == BIAS_BEARISH && close_price < m15_sl.price)
   {
      result.direction = BIAS_BEARISH;
      result.swing_high_used = m15_sh.price;
      result.swing_low_used = m15_sl.price;
      // Order Block = last bullish candle before bearish impulse
      FindM15OrderBlock(m15_bars, m15_sl.bar_index, true, result.ob_high, result.ob_low);
      result.time = m15_bars[0].time;
      result.expiry = result.time + 12 * PeriodSeconds(PERIOD_H1);
      result.valid = true;
   }
}

void FindM15OrderBlock(const MqlRates &bars[], int impulse_idx, bool find_bullish,
                       double &ob_high, double &ob_low)
{
   for(int i = impulse_idx; i < ArraySize(bars); i++)
   {
      bool is_bullish = (bars[i].close > bars[i].open);
      if(find_bullish == is_bullish)
      {
         // Order Block = body range (Open to Close)
         ob_high = MathMax(bars[i].open, bars[i].close);
         ob_low  = MathMin(bars[i].open, bars[i].close);
         return;
      }
   }
}
```

### 2.4 Fibonacci OTE Zone Calculation

```mql5
struct OTE_Zone
{
   double fib_618;     // 61.8% retracement level
   double fib_705;     // 70.5% retracement level (midpoint reference)
   double fib_786;     // 78.6% retracement level
   double zone_high;   // Upper boundary of entry zone
   double zone_low;    // Lower boundary of entry zone
   double swing_high;  // Source swing high
   double swing_low;   // Source swing low
   bool   valid;
};

bool CalculateOTE(ENUM_BIAS direction, double swing_high, double swing_low,
                  double min_width_pts, double max_width_pts, OTE_Zone &zone)
{
   double range = swing_high - swing_low;
   if(range <= 0) return false;
   
   if(direction == BIAS_BULLISH)
   {
      // Retracement from high downward: level = high - range * ratio
      zone.fib_618 = swing_high - range * 0.618;
      zone.fib_705 = swing_high - range * 0.705;
      zone.fib_786 = swing_high - range * 0.786;
      zone.zone_high = zone.fib_618;  // Shallowest level
      zone.zone_low  = zone.fib_786;  // Deepest level
   }
   else // BIAS_BEARISH
   {
      // Retracement from low upward: level = low + range * ratio
      zone.fib_618 = swing_low + range * 0.618;
      zone.fib_705 = swing_low + range * 0.705;
      zone.fib_786 = swing_low + range * 0.786;
      zone.zone_low  = zone.fib_618;  // Shallowest level
      zone.zone_high = zone.fib_786;  // Deepest level
   }
   
   zone.swing_high = swing_high;
   zone.swing_low  = swing_low;
   
   // Validate zone width
   double width_pts = (zone.zone_high - zone.zone_low) / _Point;
   if(width_pts < min_width_pts)
   {
      LogMsg("REJECT", StringFormat("OTE zone too narrow: %.1f pts < %.1f min", width_pts, min_width_pts));
      zone.valid = false;
      return false;
   }
   if(width_pts > max_width_pts)
   {
      LogMsg("REJECT", StringFormat("OTE zone too wide: %.1f pts > %.1f max", width_pts, max_width_pts));
      zone.valid = false;
      return false;
   }
   
   zone.valid = true;
   return true;
}
```

### 2.5 Confirmation Candle Detection

```mql5
enum ENUM_CANDLE_PATTERN
{
   PATTERN_NONE = 0,
   PATTERN_BULLISH_ENGULFING,
   PATTERN_BEARISH_ENGULFING,
   PATTERN_DOJI_FOLLOW,
   PATTERN_PIN_BAR
};

// Engulfing: current body fully contains previous body
bool IsBullishEngulfing(const MqlRates &curr, const MqlRates &prev)
{
   double curr_body_high = MathMax(curr.open, curr.close);
   double curr_body_low  = MathMin(curr.open, curr.close);
   double prev_body_high = MathMax(prev.open, prev.close);
   double prev_body_low  = MathMin(prev.open, prev.close);
   
   return (curr.close > curr.open) &&              // Current is bullish
          (curr_body_high >= prev_body_high) &&     // Contains prev body
          (curr_body_low <= prev_body_low) &&
          (curr.close > prev.open);                 // Closes above prev open
}

bool IsBearishEngulfing(const MqlRates &curr, const MqlRates &prev)
{
   double curr_body_high = MathMax(curr.open, curr.close);
   double curr_body_low  = MathMin(curr.open, curr.close);
   double prev_body_high = MathMax(prev.open, prev.close);
   double prev_body_low  = MathMin(prev.open, prev.close);
   
   return (curr.close < curr.open) &&              // Current is bearish
          (curr_body_high >= prev_body_high) &&     // Contains prev body
          (curr_body_low <= prev_body_low) &&
          (curr.close < prev.open);                 // Closes below prev open
}

// Doji: body < 20% of total range
bool IsDoji(const MqlRates &bar)
{
   double range = bar.high - bar.low;
   if(range <= 0) return false;
   double body = MathAbs(bar.close - bar.open);
   return (body < 0.20 * range);
}

// Pin Bar: rejection wick >= 60% of total range
bool IsPinBar(const MqlRates &bar, ENUM_BIAS bias_direction)
{
   double range = bar.high - bar.low;
   if(range <= 0) return false;
   
   double upper_wick = bar.high - MathMax(bar.open, bar.close);
   double lower_wick = MathMin(bar.open, bar.close) - bar.low;
   
   if(bias_direction == BIAS_BULLISH)
   {
      // Bullish pin bar: long lower wick (rejection of lower prices)
      return (lower_wick >= 0.60 * range);
   }
   else
   {
      // Bearish pin bar: long upper wick (rejection of higher prices)
      return (upper_wick >= 0.60 * range);
   }
}

ENUM_CANDLE_PATTERN DetectConfirmation(const MqlRates &m5_bars[], ENUM_BIAS bias,
                                        const OTE_Zone &ote)
{
   // Check if current price is within OTE zone
   double close_price = m5_bars[0].close;
   if(close_price < ote.zone_low || close_price > ote.zone_high)
      return PATTERN_NONE;
   
   if(bias == BIAS_BULLISH)
   {
      if(IsBullishEngulfing(m5_bars[0], m5_bars[1]))
         return PATTERN_BULLISH_ENGULFING;
      if(IsPinBar(m5_bars[0], BIAS_BULLISH))
         return PATTERN_PIN_BAR;
      // Doji check: previous bar was doji, current bar closed bullish
      if(IsDoji(m5_bars[1]) && m5_bars[0].close > m5_bars[0].open)
         return PATTERN_DOJI_FOLLOW;
   }
   else if(bias == BIAS_BEARISH)
   {
      if(IsBearishEngulfing(m5_bars[0], m5_bars[1]))
         return PATTERN_BEARISH_ENGULFING;
      if(IsPinBar(m5_bars[0], BIAS_BEARISH))
         return PATTERN_PIN_BAR;
      // Doji check: previous bar was doji, current bar closed bearish
      if(IsDoji(m5_bars[1]) && m5_bars[0].close < m5_bars[0].open)
         return PATTERN_DOJI_FOLLOW;
   }
   
   return PATTERN_NONE;
}
```

### 2.6 Order Execution with SL/TP Placement

```mql5
struct TradeSetup
{
   ENUM_BIAS            direction;
   ENUM_CANDLE_PATTERN  pattern;
   double               entry_price;
   double               stop_loss;
   double               tp1;
   double               tp2;
   double               lot_size;
   double               risk_money;
   double               sl_distance_pts;
};

bool BuildTradeSetup(ENUM_BIAS direction, double entry_price, const BOS_Event &bos,
                     TradeSetup &setup)
{
   setup.direction = direction;
   setup.entry_price = entry_price;
   
   // Calculate SL from M15 Order Block + buffer
   double sl_buffer = InpSLBufferDollars * 100 * _Point;  // Convert dollars to price
   
   if(direction == BIAS_BULLISH)
      setup.stop_loss = bos.ob_low - sl_buffer;
   else
      setup.stop_loss = bos.ob_high + sl_buffer;
   
   // Enforce SL bounds
   double sl_dist = MathAbs(entry_price - setup.stop_loss);
   double min_sl = InpMinSLDollars * 100 * _Point;
   double max_sl = InpMaxSLDollars * 100 * _Point;
   
   if(sl_dist < min_sl)
   {
      // Clamp to minimum
      if(direction == BIAS_BULLISH)
         setup.stop_loss = entry_price - min_sl;
      else
         setup.stop_loss = entry_price + min_sl;
      sl_dist = min_sl;
   }
   
   if(sl_dist > max_sl)
   {
      LogMsg("REJECT", StringFormat("SL too wide: %.2f > %.2f max", sl_dist/_Point, max_sl/_Point));
      return false;
   }
   
   setup.sl_distance_pts = sl_dist / _Point;
   
   // Calculate TP levels
   if(direction == BIAS_BULLISH)
   {
      setup.tp1 = entry_price + sl_dist * InpRR_TP1;
      setup.tp2 = entry_price + sl_dist * InpRR_TP2;
   }
   else
   {
      setup.tp1 = entry_price - sl_dist * InpRR_TP1;
      setup.tp2 = entry_price - sl_dist * InpRR_TP2;
   }
   
   // Calculate position size
   double risk_money = AccountInfoDouble(ACCOUNT_BALANCE) * (InpRiskPercent / 100.0);
   setup.risk_money = risk_money;
   setup.lot_size = CalcVolume(risk_money, entry_price, setup.stop_loss);
   
   if(setup.lot_size <= 0) return false;
   
   return true;
}
```

### 2.7 Partial Close at TP1 + Break-Even Management

```mql5
void ManageOpenPosition()
{
   ulong ticket = MyTicket();
   if(ticket == 0) return;
   
   if(!PositionSelectByTicket(ticket)) return;
   
   // Check minimum hold time
   datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   if(TimeCurrent() - open_time < InpMinHoldSeconds)
      return;  // Suppress all management during hold period
   
   double entry    = PositionGetDouble(POSITION_PRICE_OPEN);
   double current  = PositionGetDouble(POSITION_PRICE_CURRENT);
   double volume   = PositionGetDouble(POSITION_VOLUME);
   double sl       = PositionGetDouble(POSITION_SL);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   double sl_dist = MathAbs(entry - sl);
   double tp1_price = (type == POSITION_TYPE_BUY) 
                      ? entry + sl_dist * InpRR_TP1 
                      : entry - sl_dist * InpRR_TP1;
   double tp2_price = (type == POSITION_TYPE_BUY)
                      ? entry + sl_dist * InpRR_TP2
                      : entry - sl_dist * InpRR_TP2;
   
   // Check TP1 hit (if not already partially closed)
   bool tp1_reached = (type == POSITION_TYPE_BUY) 
                      ? (current >= tp1_price) 
                      : (current <= tp1_price);
   
   if(tp1_reached && !g_tp1Hit)
   {
      double close_lots = MathFloor(volume * (InpPartialClosePercent / 100.0) 
                          / g_lotStep) * g_lotStep;
      double remaining = volume - close_lots;
      
      if(remaining < g_lotMin)
      {
         // Close entire position at TP1
         trade.PositionClose(ticket);
      }
      else
      {
         // Partial close
         trade.PositionClosePartial(ticket, close_lots);
         // Move SL to break-even
         trade.PositionModify(ticket, entry, tp2_price);
      }
      g_tp1Hit = true;
   }
   
   // Check TP2 hit
   bool tp2_reached = (type == POSITION_TYPE_BUY)
                      ? (current >= tp2_price)
                      : (current <= tp2_price);
   if(tp2_reached && g_tp1Hit)
   {
      trade.PositionClose(ticket);
   }
}
```

### 2.8 Static DD and Daily Loss Tracking

```mql5
// Static Drawdown: measured from initial balance (not equity high)
void CheckStaticDrawdown()
{
   double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double dd_percent = (InpInitialBalance - current_balance) / InpInitialBalance * 100.0;
   
   if(dd_percent >= InpStaticDDPercent)
   {
      // Emergency: close all positions
      CloseAllPositions();
      g_ddTriggered = true;
      LogMsg("ALERT", StringFormat("STATIC DD TRIGGERED: Balance=%.2f, Loss=%.2f, DD=%.2f%%",
             current_balance, InpInitialBalance - current_balance, dd_percent));
   }
}

// Daily Loss: measured from day-start balance (realized P&L only)
void CheckDailyLoss()
{
   double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double day_loss = g_dayStartBalance - current_balance;
   double day_loss_percent = day_loss / g_dayStartBalance * 100.0;
   
   if(day_loss_percent >= InpDailyLossPercent)
   {
      g_dailyLossTriggered = true;
      LogMsg("WARNING", StringFormat("DAILY LOSS LIMIT: Loss=%.2f (%.2f%%), DayStart=%.2f",
             day_loss, day_loss_percent, g_dayStartBalance));
   }
}
```

---

## 3. State Machine: Setup Lifecycle

### 3.1 State Diagram

```
                    ┌─────────────────────────────────────────────┐
                    │                                             │
                    ▼                                             │
    ┌────────┐  H1 CHoCH   ┌──────────────────┐                 │
    │  IDLE  │─────────────▶│ H1_CHOCH_DETECTED│                 │
    └────────┘              └────────┬─────────┘                 │
        ▲                           │                            │
        │                    Price enters                        │
        │                    H1 POI zone                         │
        │                           │                            │
        │                           ▼                            │
        │               ┌───────────────────────┐               │
        │               │ WAITING_FOR_POI_RETEST│               │
        │               └───────────┬───────────┘               │
        │                           │                            │
        │                    M15 BOS confirmed                   │
        │                           │                            │
        │                           ▼                            │
        │               ┌───────────────────────┐               │
        │               │   M15_BOS_CONFIRMED   │               │
        │               └───────────┬───────────┘               │
        │                           │                            │
        │                    OTE zone calculated                 │
        │                    + validated                          │
        │                           │                            │
        │                           ▼                            │
        │               ┌───────────────────────┐   Timeout/    │
        │               │ WAITING_FOR_OTE_ENTRY │───Invalidate──┘
        │               └───────────┬───────────┘
        │                           │
        │                    Confirmation candle
        │                    + all filters pass
        │                           │
        │                           ▼
        │               ┌───────────────────────┐
        │               │    POSITION_OPEN      │
        │               └───────────┬───────────┘
        │                           │
        │                    TP1 hit + partial close
        │                    + BE applied
        │                           │
        │                           ▼
        │               ┌───────────────────────┐
        │               │      TP1_HIT          │
        │               └───────────┬───────────┘
        │                           │
        │                    TP2 hit OR SL (at BE)
        │                           │
        │                           ▼
        │               ┌───────────────────────┐
        └───────────────│      COMPLETED        │
                        └───────────────────────┘
```

### 3.2 State Transitions

| Current State | Trigger | Next State | Actions |
|---|---|---|---|
| IDLE | H1 CHoCH detected | H1_CHOCH_DETECTED | Store bias, POI zone |
| H1_CHOCH_DETECTED | Price touches H1 POI zone | WAITING_FOR_POI_RETEST | Mark POI tested |
| WAITING_FOR_POI_RETEST | M15 BOS in bias direction | M15_BOS_CONFIRMED | Store OB zone |
| M15_BOS_CONFIRMED | OTE zone calculated + valid | WAITING_FOR_OTE_ENTRY | Store fib levels |
| WAITING_FOR_OTE_ENTRY | Confirmation candle + filters pass | POSITION_OPEN | Place market order |
| WAITING_FOR_OTE_ENTRY | Timeout (12 H1 bars) | IDLE | Clear all zones |
| WAITING_FOR_OTE_ENTRY | Price passes through OTE without entry | IDLE | Clear setup |
| WAITING_FOR_OTE_ENTRY | Opposing H1 CHoCH | IDLE | Invalidate setup |
| POSITION_OPEN | TP1 reached + hold time elapsed | TP1_HIT | Partial close + BE |
| POSITION_OPEN | SL hit (by broker) | IDLE | Position closed |
| TP1_HIT | TP2 reached | IDLE | Close remaining |
| TP1_HIT | SL at BE hit (by broker) | IDLE | Position closed at BE |
| ANY (except IDLE) | Opposing CHoCH on H1 | IDLE (if no position) | Invalidate zones |
| ANY | Static DD triggered | DISABLED | Close all, halt |

### 3.3 State Implementation

```mql5
enum ENUM_SETUP_STATE
{
   STATE_IDLE = 0,
   STATE_H1_CHOCH_DETECTED,
   STATE_WAITING_FOR_POI_RETEST,
   STATE_M15_BOS_CONFIRMED,
   STATE_WAITING_FOR_OTE_ENTRY,
   STATE_POSITION_OPEN,
   STATE_TP1_HIT,
   STATE_DISABLED
};

// Global state
ENUM_SETUP_STATE g_state = STATE_IDLE;
CHoCH_Event      g_choch;
BOS_Event        g_bos;
OTE_Zone         g_ote;
bool             g_tp1Hit = false;
bool             g_ddTriggered = false;
bool             g_dailyLossTriggered = false;

void TransitionState(ENUM_SETUP_STATE new_state, string reason)
{
   LogMsg("STATE", StringFormat("%s -> %s | %s",
          EnumToString(g_state), EnumToString(new_state), reason));
   g_state = new_state;
}

void InvalidateSetup(string reason)
{
   if(g_state != STATE_POSITION_OPEN && g_state != STATE_TP1_HIT)
   {
      g_choch.valid = false;
      g_bos.valid = false;
      g_ote.valid = false;
      TransitionState(STATE_IDLE, "Invalidated: " + reason);
   }
}
```

---

## 4. Data Models

### 4.1 Core Structures

```mql5
// Already defined above, consolidated here for reference:

struct SwingPoint
{
   double   price;
   datetime time;
   int      bar_index;
   bool     is_high;
};

struct CHoCH_Event
{
   ENUM_BIAS   direction;
   double      swing_broken;
   datetime    time;
   double      poi_high;
   double      poi_low;
   bool        valid;
};

struct BOS_Event
{
   ENUM_BIAS   direction;
   double      ob_high;
   double      ob_low;
   double      swing_high_used;
   double      swing_low_used;
   datetime    time;
   datetime    expiry;
   bool        valid;
};

struct OTE_Zone
{
   double fib_618;
   double fib_705;
   double fib_786;
   double zone_high;
   double zone_low;
   double swing_high;
   double swing_low;
   bool   valid;
};

struct TradeSetup
{
   ENUM_BIAS            direction;
   ENUM_CANDLE_PATTERN  pattern;
   double               entry_price;
   double               stop_loss;
   double               tp1;
   double               tp2;
   double               lot_size;
   double               risk_money;
   double               sl_distance_pts;
};

struct DayState
{
   datetime day_start;
   double   day_start_balance;
   int      trades_today;
   double   daily_realized_pnl;
   bool     daily_loss_triggered;
};
```

### 4.2 Input Parameters Block

```mql5
// Risk Management
input double InpRiskPercent       = 1.0;      // Risk per trade (%)
input double InpMaxLot            = 0.08;     // Maximum lot size
input double InpRR_TP1            = 2.0;      // TP1 risk-reward ratio
input double InpRR_TP2            = 3.0;      // TP2 risk-reward ratio
input int    InpPartialClosePercent = 50;     // Partial close at TP1 (%)
input int    InpMaxTradesPerDay   = 3;        // Max trades per day
input double InpDailyLossPercent  = 4.0;      // Daily loss limit (%)
input double InpStaticDDPercent   = 13.0;     // Static drawdown limit (%)
input int    InpMaxSpreadPoints   = 50;       // Max spread for entry
input int    InpMinHoldSeconds    = 120;      // Minimum hold time (sec)
input double InpSLBufferDollars   = 1.0;      // SL buffer beyond OB ($)
input double InpMinSLDollars      = 5.0;      // Minimum SL distance ($)
input double InpMaxSLDollars      = 15.0;     // Maximum SL distance ($)
input double InpInitialBalance    = 5000.0;   // Initial account balance
input long   InpMagicNumber       = 20260801; // Magic number

// Structure Detection
input int    InpH1SwingBars       = 3;        // H1 swing bars (each side)
input int    InpM15SwingBars      = 2;        // M15 swing bars (each side)
input double InpFibLevelLow       = 0.618;    // OTE lower fib level
input double InpFibLevelHigh      = 0.786;    // OTE upper fib level
input double InpMinOTEWidthDollars = 2.0;     // Min OTE zone width ($)
input double InpMaxOTEWidthDollars = 15.0;    // Max OTE zone width ($)
input int    InpSetupTimeoutH1Bars = 12;      // Setup timeout (H1 bars)

// Optional Filters
input bool   InpUseEMA200Filter   = false;    // Use EMA 200 trend filter
input int    InpEMA200Period       = 200;     // EMA period
input ENUM_TIMEFRAMES InpEMA200TF = PERIOD_H1;// EMA timeframe

// Diagnostics
input bool   InpVerboseLogs       = true;     // Verbose logging
```

---

## 5. Error Handling

### 5.1 Error Categories and Responses

| Category | Condition | Response |
|---|---|---|
| **Initialization Errors** | Wrong symbol, wrong TF, no data | `INIT_FAILED`, EA halts |
| **Data Errors** | `CopyRates` returns < requested bars | Skip current analysis cycle, retry next bar |
| **Order Errors** | `trade.Buy()`/`trade.Sell()` fails | Log retcode, do NOT retry (avoid duplicates) |
| **Modify Errors** | `PositionModify` fails (BE move) | Log error, retry on next tick (max 3 attempts) |
| **Partial Close Errors** | `PositionClosePartial` fails | Log error, attempt full close as fallback |
| **Margin Errors** | Insufficient margin | Reject trade, log, wait for next setup |
| **Static DD Emergency** | Balance <= threshold | Close all, disable permanently |

### 5.2 Recovery Patterns

```mql5
// Pattern: Safe position modification with retry
bool SafeModifySL(ulong ticket, double new_sl, double tp, int max_retries = 3)
{
   for(int attempt = 0; attempt < max_retries; attempt++)
   {
      if(trade.PositionModify(ticket, new_sl, tp))
      {
         if(IsRetcodeSuccess()) return true;
      }
      LogMsg("RETRY", StringFormat("Modify attempt %d failed: %d", attempt+1, trade.ResultRetcode()));
      Sleep(100);
   }
   LogMsg("ERROR", StringFormat("Modify failed after %d attempts, ticket=%llu", max_retries, ticket));
   return false;
}

// Pattern: Validate before acting
bool PreTradeChecks(const TradeSetup &setup)
{
   // 1. Static DD
   if(g_ddTriggered) return false;
   
   // 2. Daily loss limit
   if(g_dailyLossTriggered) return false;
   
   // 3. Max trades per day
   if(g_tradesToday >= InpMaxTradesPerDay) return false;
   
   // 4. No existing position
   if(HasPosition()) return false;
   
   // 5. Spread check
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints) return false;
   
   // 6. Margin check
   double margin_required = 0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, setup.lot_size, setup.entry_price, margin_required))
      return false;
   if(margin_required > AccountInfoDouble(ACCOUNT_MARGIN_FREE) * 0.80)
      return false;
   
   return true;
}
```

### 5.3 Defensive Coding Standards

- All `CopyRates`/`CopyBuffer` calls check return value before using data
- All `PositionSelect`/`PositionGetTicket` results validated before access
- Division operations check for zero divisor (range == 0, tick_value == 0)
- Price normalization via `NormalizeDouble` before all order operations
- Magic number filtering on ALL position queries
- State machine prevents re-entry into already-active states

---

## 6. Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Swing Detection Fractal Invariant

*For any* array of OHLC bars and any swing point returned by the detection algorithm with parameter `bars_required = N`, the swing high's High value must be strictly greater than the High of all N bars on each side, and the swing low's Low value must be strictly less than the Low of all N bars on each side.

**Validates: Requirements 1.1, 2.5**

### Property 2: CHoCH Direction Classification

*For any* H1 price series where the prior trend is identifiable and the most recent completed bar closes beyond the relevant swing point, a Bullish CHoCH shall be detected if and only if close > last_swing_high in a bearish trend, and a Bearish CHoCH shall be detected if and only if close < last_swing_low in a bullish trend.

**Validates: Requirements 1.2, 1.3**

### Property 3: POI Zone Boundary Correctness

*For any* detected CHoCH event, the POI zone boundaries must correspond to the last opposite-color candle before the impulse move: for Bullish CHoCH the POI is (Open, Low) of the last bearish candle, and for Bearish CHoCH the POI is (Open, High) of the last bullish candle.

**Validates: Requirements 1.4, 1.5**

### Property 4: Single Active Bias Invariant

*For any* sequence of CHoCH detection events, the system shall maintain exactly one bias direction at any time. After a new CHoCH is stored, querying the active bias must return the most recently detected direction and no prior bias shall remain accessible.

**Validates: Requirements 1.6**

### Property 5: BOS Precondition Enforcement

*For any* M15 bar close, a BOS event shall only be classified when all three preconditions hold simultaneously: (a) an H1 CHoCH bias is active, (b) price has retraced into or near the H1 POI zone, and (c) price breaks the relevant M15 swing in the bias direction. If any precondition is missing, no BOS shall be produced.

**Validates: Requirements 2.1, 2.2**

### Property 6: Order Block Body Range Accuracy

*For any* confirmed BOS event on M15, the Order Block boundaries must equal the body range (min(Open, Close) to max(Open, Close)) of the last opposite-color candle before the impulse that caused the BOS.

**Validates: Requirements 2.3, 2.4**

### Property 7: Fibonacci Calculation Correctness

*For any* swing high H and swing low L where H > L, the Fibonacci retracement levels must satisfy: for bullish setups, fib_618 = H - (H-L)*0.618, fib_786 = H - (H-L)*0.786; for bearish setups, fib_618 = L + (H-L)*0.618, fib_786 = L + (H-L)*0.786. The OTE zone boundaries must equal the 0.618 and 0.786 levels.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4**

### Property 8: OTE Zone Width Validation

*For any* calculated OTE zone, if the width (zone_high - zone_low) is less than `min_width` or greater than `max_width`, the setup must be rejected and `zone.valid` must be false.

**Validates: Requirements 3.5, 3.6**

### Property 9: Engulfing Pattern Detection Correctness

*For any* two consecutive candles, Bullish Engulfing is detected if and only if (a) the current candle is bullish, (b) the current body fully contains the previous body, and (c) the current close is above the previous open. Bearish Engulfing is the exact mirror with bearish current candle and close below previous open.

**Validates: Requirements 4.5, 4.6**

### Property 10: Doji Classification Correctness

*For any* single candle, the Doji classification returns true if and only if |Close - Open| < 0.20 * (High - Low), where High - Low > 0.

**Validates: Requirements 4.7**

### Property 11: Stop Loss Calculation and Bounds Enforcement

*For any* trade setup with entry price E and M15 Order Block boundaries, the stop loss must equal OB_boundary ± buffer, clamped to [min_sl, max_sl] distance from entry. If the raw distance exceeds max_sl, the trade must be rejected.

**Validates: Requirements 5.1, 5.2, 5.3, 5.4**

### Property 12: Take Profit Level Calculation

*For any* trade with entry price E and SL distance D, TP1 must equal E ± (D × RR_TP1) and TP2 must equal E ± (D × RR_TP2), where the sign matches the trade direction.

**Validates: Requirements 6.1, 6.2**

### Property 13: Partial Close Volume Correctness

*For any* position volume V and lot_step S, the partial close amount must equal floor(V × partial_percent / 100 / S) × S. If the remaining volume after partial close is below minimum lot, the entire position must be closed.

**Validates: Requirements 6.3, 6.6**

### Property 14: Lot Size Calculation and Normalization

*For any* account balance B, risk percent R, SL distance D (in points), and point value P, the calculated lot must satisfy: raw_lot = (B × R/100) / (D × P), final_lot = min(floor(raw_lot / lot_step) × lot_step, max_lot). If final_lot < min_lot, the trade must be rejected.

**Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5**

### Property 15: Daily Loss Threshold Enforcement

*For any* day_start_balance and sequence of realized losses within a trading day, when cumulative losses reach or exceed 4% of day_start_balance, all subsequent trade attempts in that day must be rejected. After a day reset, trading must resume.

**Validates: Requirements 8.2, 8.3, 8.5**

### Property 16: Static Drawdown Calculation and Halt

*For any* initial balance I and current balance C, static drawdown equals (I - C) / I × 100. When this value reaches or exceeds the configured threshold, all positions must be closed and no new trades shall be permitted until restart.

**Validates: Requirements 9.2, 9.3, 9.4**

### Property 17: Single Position Invariant

*For any* state of the EA, the number of open positions with the assigned magic number shall never exceed 1. Any entry signal generated while a position is open must be discarded.

**Validates: Requirements 10.4, 10.5, 18.1, 18.4**

### Property 18: Daily Trade Count Cap

*For any* trading day, the number of successfully filled trades (counted on fill, not on signal) shall not exceed the configured maximum. Once the limit is reached, no new entries are permitted until the next day reset.

**Validates: Requirements 10.1, 10.2, 10.3**

### Property 19: Minimum Hold Time Suppression

*For any* open position with age T < min_hold_seconds, all EA-initiated modifications (partial close, break-even move, take-profit close) must be suppressed. For any position with age T >= min_hold_seconds, these operations must be permitted.

**Validates: Requirements 11.1, 11.3, 11.4**

### Property 20: Spread Filter Enforcement

*For any* entry signal, if the current spread exceeds the configured maximum spread, the trade must be rejected. If the spread is at or below the maximum, the spread check must pass.

**Validates: Requirements 12.2**

### Property 21: Magic Number Isolation

*For any* position on the account, the EA shall only manage (query, modify, close) positions whose magic number matches the configured value. Positions with non-matching magic numbers must be completely ignored.

**Validates: Requirements 13.1, 13.2, 13.3**

### Property 22: Setup Invalidation on Opposing CHoCH

*For any* pending BOS/OTE setup, if a new CHoCH is detected on H1 in the direction opposing the current bias, the setup must be immediately invalidated (all zone data cleared, state returns to IDLE).

**Validates: Requirements 2.6, 14.2**

### Property 23: Setup Timeout Invalidation

*For any* BOS signal that has been active longer than the configured timeout (12 H1 bars) without triggering an M5 entry, the setup must be invalidated and all pending zone data cleared.

**Validates: Requirements 14.1**

### Property 24: No Martingale Lot Increase

*For any* two consecutive trades where the first trade resulted in a loss, the lot size of the second trade must be computed solely from the lot formula (balance × risk / SL) and must not incorporate any multiplier or increase based on the prior loss outcome.

**Validates: Requirements 18.2**

### Property 25: Market Orders Only

*For any* order placed by the EA, the order type must be `ORDER_TYPE_BUY` or `ORDER_TYPE_SELL` (market execution). The EA must never place pending orders (`ORDER_TYPE_BUY_LIMIT`, `ORDER_TYPE_SELL_STOP`, etc.).

**Validates: Requirements 18.5**

---

## 7. File Structure

The EA is implemented as a single `.mq5` file with logical sections following the pattern established by `CK_GFT_Fast2_V811.mq5`:

```
CK_XAU_ICT_ChoCh_V1.mq5
├── Header (copyright, version, #property)
├── #include <Trade/Trade.mqh>
├── Input Parameters Block
├── Enum Definitions (ENUM_BIAS, ENUM_SETUP_STATE, ENUM_CANDLE_PATTERN)
├── Struct Definitions (SwingPoint, CHoCH_Event, BOS_Event, OTE_Zone, TradeSetup, DayState)
├── Global State Variables
├── Utility Functions (Price normalization, logging, tick helpers)
├── Swing Detection Functions (IsSwingHigh, IsSwingLow)
├── H1 Analysis (DetectCHoCH, FindPOI)
├── M15 Analysis (DetectBOS, FindM15OrderBlock, CalculateOTE)
├── M5 Analysis (Confirmation candle detection)
├── Risk/Protection Layer (CalcVolume, PreTradeChecks, CheckStaticDrawdown, CheckDailyLoss)
├── Trade Execution (BuildTradeSetup, ExecuteTrade)
├── Trade Management (ManageOpenPosition, partial close, BE)
├── State Machine (TransitionState, InvalidateSetup)
├── OnInit() — validation, indicator handles, data loading
├── OnDeinit() — cleanup
└── OnTick() — main event loop
```
