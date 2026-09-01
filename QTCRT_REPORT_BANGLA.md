# QT / CRT strategy — MT5 backtest + improve চেষ্টা (বাংলা)

- EA: **CK_QT_CRT_v1.mq5** — ৪টা decoded PDF (Quarterly Theory / CRT / DOL / Daily Bias) থেকে faithful mechanical build
- Core: **CRT "Power of Three" sweep-reversal** (একটা closed M15 candle recent swing high/low সুইপ করে ভেতরে ক্লোজ) + True-Open bias thermometer + killzone time-gate + DOL (opposite liquidity) target
- SMT/PSP **বাদ** — XAUUSD-তে পরিষ্কার correlated triad নেই (সৎভাবে জানানো)
- MT5 Strategy Tester only; deposit $50k; সব input pinned (Guard #20); ledger seq 103-107 (verified)

## Baseline (consolidation OFF)
| উইন্ডো | ট্রেড | PF | win% | exp/ট্রেড |
|---|---|---|---|---|
| IS (জুন–ডিসে ২০২৫) | 96 | **1.24** | 40.6% | +$9.2 |
| OOS (ডিসে ২০২৫–আগ ২০২৬) | 155 | **0.76** | 34.2% | −$20.5 |
| cr_h1 | 85 | 0.90 | 41% | −$8 |
| cr_h2 | 99 | 0.80 | 32% | −$16 |

IS দুর্বলভাবে লাভজনক, কিন্তু OOS ও দুই regime-অর্ধই লোকসান।

## Improvement A (spec-faithful): MODEL condition #1 = consolidation filter ON
| উইন্ডো | ট্রেড | PF | win% |
|---|---|---|---|
| IS | 80 | **0.91** (↓ লোকসান) | 40% |
| OOS | 106 | 0.83 | 36.8% |
| cr_h1 | 65 | 0.73 | 40% |
| cr_h2 | 68 | 0.94 | 36.8% |

consolidation গেট চালু করে **উল্টো খারাপ** হলো — IS-ও লোকসানি (বড় expansion-winner কেটে গেল, avg_win $১১৬→$৮১)। **৩ শর্তের একটিও পাস করেনি।**

## কেন — মূল রোগ
QT/CRT-র win rate ভালো (৩৪–৪১%, QM/ICT-র ৮–১২%-এর চেয়ে অনেক ভালো), কিন্তু realized RR মাত্র ~১.৫। এই RR-এ breakeven win rate ~৪০%। OOS-এ actual win rate ৩৪–৩৭% → breakeven-এর সামান্য নিচে → **bleeds**। IS-এ উপরে ছিল, OOS-এ নিচে — ঠিক আগের সব strategy-র মতোই প্যাটার্ন।

## সিদ্ধান্ত (সৎ)
- **QT/CRT-ও এই XAUUSD real-tick ডেটায় robust, current edge দেখায় না।**
- একটা pre-registered, spec-faithful improvement (consolidation) চেষ্টা করেছি — কাজ করেনি (বরং খারাপ)। **এর বেশি variant চাপানো = overfitting/fishing**, যা প্রজেক্টের নিয়মে নিষিদ্ধ — তাই থেমেছি।
- কোনো parameter sweep/profit-tuning করিনি; কোনো লাইভ/আসল-টাকা পদক্ষেপ নেওয়া হয়নি।

## সীমাবদ্ধতা (স্বীকার)
- এটা ৪টা doc-এর আমার **mechanical ব্যাখ্যা**; True-Open/consolidation/CRT-র সংজ্ঞায় বাস্তবায়ন-সিদ্ধান্ত আছে।
- SMT/PSP ও discretionary DOL-read (৮:৩০/৯:৩০ manipulation) mechanize করা হয়নি (docs নিজেই বলেছে discretionary)।
- server time = NY কিনা যাচাই করা হয়নি (killzone hours আনুমানিক)।

## সামগ্রিক (৫টি strategy পরিবার)
Trend (FIX09/v23), Volume-profile (POC_VA), ICT (QM/ICT), এখন QT/CRT — **কোনোটিই robust current edge দেয় না।** সবগুলোর একই failure: IS ঠিক, OOS-এ ভেঙে পড়ে / regime-অসঙ্গত। এটাই সৎ, প্রমাণভিত্তিক ফলাফল — আর এই MT5-only যাচাই-ল্যাব + hash-chained ledger-ই আসল deliverable।

---
*সব ট্রেড MT5-এ (real ticks); Python শুধু হিসাব; সব input pinned; সব রান ledger-এ (seq 103-107, verified)।*
