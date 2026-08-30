# SESSION EXPORT — CK GFT Fast EA (GOAT $1 Model, XAUUSD)

> **এই ডকুমেন্টটি একটি Kiro সেশনের সম্পূর্ণ রেকর্ড।** ভবিষ্যতের যেকোনো এজেন্ট/মানুষ যেন কাজটা
> সম্পূর্ণভাবে বুঝে চালিয়ে যেতে পারে, সেজন্য সবকিছু সৎভাবে ও বিস্তারিতভাবে লেখা হয়েছে।
> কোনো ফলাফল বানানো হয়নি। যেখানে অনিশ্চয়তা আছে, সেখানে স্পষ্ট বলা হয়েছে।

- **Export তারিখ:** 2026-07-31 (সেশনের current date)
- **Repo:** https://github.com/rupamsaha704-svg/CK_GFT_Fast2_V820_FIXED
- **কাজের ব্রাঞ্চ (এই সেশনে EA আপডেট হয়েছিল):** `goat1-v812-fixed-sl-tp`
- **এই export যে ব্রাঞ্চে লেখা হচ্ছে:** `kiro/validation-toolkit`
- **প্রধান ফাইল:** `CK_GFT_Fast_v8.12_GOAT1.mq5` (ফাইলের নাম v8.12 থাকলেও ভিতরের কোড শেষে v8.19 হয়েছে)
- **ব্যবহারকারীর ভাষা:** বাংলা (সব যোগাযোগ বাংলায়)

---

## ⚠️ সবচেয়ে গুরুত্বপূর্ণ সতর্কবার্তা (আগে পড়ুন)

**এই সেশনে বানানো EA কখনোই লাভজনক (profitable) হয়নি। প্রতিটি ব্যাকটেস্ট নেট লসে শেষ হয়েছে।**
Win rate বেশি (~83%) হলেও, লসগুলো উইনের চেয়ে অনেক বড় ছিল — তাই Profit Factor < 1 (লসে)।
ব্যবহারকারীকে ভুল আশা দেওয়া হয়নি এমন নয় — বাস্তবতা হলো strategy টা এখনো কাজ করছে না।
একজন ভবিষ্যৎ এজেন্টের এটা জানা জরুরি: **প্রথম কাজ হওয়া উচিত strategy-র edge আছে কিনা যাচাই করা,
কোড টিউনিং নয়।**

---

## ১. PURPOSE (সেশনের উদ্দেশ্য)

ব্যবহারকারী **GOAT Funded Trader (GFT)-এর "Goat $1 Model"** ($1,000 ফান্ডেড অ্যাকাউন্ট, দাম $1)
পাস করতে চান এবং সেখান থেকে $100 (lifetime max withdrawable) তুলতে চান — **80% profit split**, তাই
নিট $80 পাবেন।

- লক্ষ্য: একটি MQL5 Expert Advisor (EA) দিয়ে **XAUUSD** (Gold)-এ **প্রতিদিন ~$10 profit** করা,
  **১০-১৫ দিনে $100** জমিয়ে একবারে withdraw করা।
- অ্যাকাউন্টের মেয়াদ **activation-এর ২৮ দিন**, তাই সময় সীমিত। ব্যবহারকারী বারবার বলেছেন হাতে
  **১৫-১৮ দিন** আছে।
- ব্যবহারকারী GFT support-এর সাথে কথা বলে নিশ্চিত করেছেন যে **AI দিয়ে বানানো custom EA ব্যবহার করা
  অনুমোদিত**, যতক্ষণ strategy/rules নিজের এবং কোনো prohibited practice নেই।

শুরুতে ব্যবহারকারী একটি বিদ্যমান EA ("CK GFT Fast" v8.10) পেস্ট করেছিলেন এবং GFT rules-এর সাথে
মিলিয়ে সেটা compliant করতে বলেছিলেন।

---

## ২. GFT "GOAT $1 MODEL" — সম্পূর্ণ নিয়ম (ব্যবহারকারীর দেওয়া FAQ + Support chat PDF থেকে)

| বিষয় | নিয়ম |
|------|------|
| Access Type | Immediate Funded |
| Account Size | $1,000 |
| Price | $1 |
| **Daily Drawdown** | **3% (Trailing)** — $1000 এ $30; ৫ PM EST rollover-এ balance/equity-র উচ্চতর মানের ভিত্তিতে |
| **Max Overall Loss** | **6% (Trailing)** — দিনের শেষে equity বাড়লে threshold ওপরে ওঠে, কমলে নামে না |
| **Maximum Floating Loss** | **2%** — কোনো মুহূর্তে combined open-trade loss balance-এর 2% ($20) ছাড়ালে account **permanently closed** |
| Minimum Trading Days | প্রতি payout-এ **3 Valid Trading Days** |
| Valid Day সংজ্ঞা | সেদিন কমপক্ষে **0.5% profit** ($5) করতে হবে |
| **Consistency Rule** | **15%** — কোনো একদিনের profit মোট payout-period profit-এর 15%-এর বেশি হতে পারবে না |
| Profit Split | 80% |
| Reward Cycle | প্রতি 14 দিন |
| Account Expiry | Activation-এর **28 দিন** পরে |
| Minimum Payout Request | **$100** (30 July 2026 থেকে কেনা account-এ) |
| Max Lifetime Withdrawable | **$100** |
| Purchase Limit | 1 account/user |

### নিষিদ্ধ practices (payout reject হবে):
- **High-Frequency Trading (HFT)**
- **Gold Arbitrage EA**
- Arbitrage / latency exploitation
- Third-party / rented / purchased / challenge-passing EA
- একই asset-এ opposite-position **hedging**
- **Martingale** strategy
- Copy trading (বিশেষত evaluation/challenge phase)
- Account sharing

### ⭐ অত্যন্ত গুরুত্বপূর্ণ — ২ মিনিট রুল:
> **২ মিনিটের কম সময় ধরে রাখা trade-এর profit payout থেকে বাদ দেওয়া হতে পারে।**
> তাই প্রতিটি trade কমপক্ষে ২ মিনিট ধরে রাখতে হবে। এই কারণেই **scalping / 5-pip strategy করা যাবে না।**

### Payout verification-এ যা চাইতে পারে (evidence):
- Original strategy specs ও input rules
- AI prompt/chat history (যেখানে strategy ও modification instruction দেওয়া হয়েছে)
- MQL5 source/project files ও বিভিন্ন version
- MetaEditor compile records / screenshots
- Backtest reports, Change log, MT5 journal/logs, Myfxbook history
- Full source code সবসময় বাধ্যতামূলক নয়, তবে verification-এ চাইতে পারে

---

## ৩. ব্রোকার / সিম্বল স্পেসিফিকেশন (ব্যবহারকারী নিশ্চিত করেছেন)

MetaQuotes-Demo (Hedge account), XAUUSD:
- **Contract Size = 100** (1.00 lot = 100 oz Gold)
- **Volume Min = 0.01**
- **Volume Step = 0.01**
- **Volume Max = 100**
- **Tick Size = 0.01**
- **Tick Value = 0.1**
- Digits = 2 (Gold দাম যেমন 4894.51)
- Leverage: **1:20** (GFT-তে সর্বোচ্চ, এর বেশি হয় না)

> **CRITICAL কারিগরি সমস্যা যা আবিষ্কৃত হয়েছে:** XAUUSD-এ **tick_value ফ্লোটিং** — Gold-এর দামের
> লেভেলের সাথে বদলায়। এই backtest-এ Gold দাম ~$4300 থেকে ~$5500 পর্যন্ত উঠেছিল। ফলে একই "price
> distance" নিচু দামে $10 হলেও উঁচু দামে $17 হয়ে যাচ্ছিল। এই কারণেই TP ঠিক $10 দেখালেও SL হিট
> হলে লস $17-$18 হচ্ছিল। (নিচে WARNINGS সেকশনে বিস্তারিত।)

---

## ৪. STRATEGY RULES (ট্রেডিং সেটআপ লজিক)

মূল strategy = **"Knee pattern" pullback (শুধু BUY, long-only)।** সেল/short লজিক কখনো যোগ হয়নি।

- **টাইমফ্রেম:** শুরুতে M5, পরে M15 সুপারিশ করা হয়েছিল (M5 তে trade খুব দ্রুত ক্লোজ হয়ে ২ মিনিট রুল
  ভাঙার ঝুঁকি)।
- **সিম্বল:** XAUUSD।
- **Entry (Knee pattern, BUY only):**
  1. একটি সবুজ (green) ক্যান্ডেল রান হতে হবে — bar[2] থেকে পিছনে কমপক্ষে `InpKneeMinRun` (=2) টি
     পরপর সবুজ ক্যান্ডেল।
  2. তারপর bar[1] হতে হবে লাল (red) — এটাই "knee" (pullback)।
  3. Trend filter (যদি `InpUseTrend=true`): EMA(21) > EMA(50) এবং close[1] > EMA(21) —
     অর্থাৎ uptrend।
  4. শর্ত মিললে "ARM" হয়: trigger = knee ক্যান্ডেলের High (`iHigh(bar1)`)।
  5. পরের কয়েক bar (`InpValidBars`=5) এর মধ্যে দাম trigger ছুঁলে BUY ওপেন হয়।
- **Lot:** ফিক্সড **0.02** (martingale নয়, বাড়ে না)।
- **TP:** **$10 profit** (0.02 লটে ≈ 50 points/price move ~5.00 Gold ডলার)।
- **SL:** **$10 loss** (একই দূরত্ব) — RR 1:1। *(বাস্তবে tick_value সমস্যায় লস বেশি হচ্ছিল।)*
- **Break-Even (BE):** profit +$6 হলে SL entry-তে সরে যায় (ট্রেড ফ্রি হয়ে যায়)।
- **Daily target:** $10 হলে সেদিন আর কোনো ট্রেড নয়।
- **Loss হলে:** সেদিন আর কোনো ট্রেড নয় (state = DONE_LOSS)।
- **BE-তে ক্লোজ হলে (0 লস):** আগের কিছু ভার্সনে retry allowed ছিল; শেষ ভার্সনে (state machine)
  BE-ও DONE হিসেবে গণ্য — অর্থাৎ কার্যত **দিনে ১টাই ট্রেড**।

### ব্যবহারকারীর "$10 প্রতিদিন" প্ল্যান ও Consistency Rule যাচাই:
প্রতিদিন সমান $10 করলে, 10 দিনে $100; প্রতিদিনের share = $10/$100 = **10% < 15%** → consistency
rule পাস। এটা গাণিতিকভাবে সঠিক এবং সেশনে নিশ্চিত করা হয়েছে।

### ব্যবহারকারীর একটি প্রস্তাব যা প্রত্যাখ্যান করা হয়েছে:
শেষদিকে ব্যবহারকারী **"5 pip SL / 5 pip TP, liquidity injection scalping"** চেয়েছিলেন। এটা
**করা যাবে না** কারণ — (a) HFT/scalping GFT-তে নিষিদ্ধ, (b) ২ মিনিট রুল ভাঙবে → profit payout
থেকে বাদ যাবে। ব্যবহারকারীকে এটা স্পষ্ট বোঝানো হয়েছে এবং তিনি ($10 target, ২ মিনিটের বেশি hold)
মূল প্ল্যানে ফেরত এসেছেন।

---

## ৫. EA ভার্সন ইতিহাস (এই সেশনে যা যা হয়েছে — সৎ ক্রম)

ফাইল নাম সবসময় `CK_GFT_Fast_v8.12_GOAT1.mq5` ছিল, কিন্তু `#property version` ভিতরে বেড়েছে:

1. **v8.10 (ইনপুট)** — ব্যবহারকারীর মূল EA। risk% ভিত্তিক lot, ATR ভিত্তিক SL, RR 2.5, দৈনিক
   R-ভিত্তিক loss/profit stop। কোনো floating-loss guard, ২-মিনিট guard, বা trailing DD ছিল না।
2. **v8.11** — যোগ করা হলো: 1.8% floating loss guard, $10 daily profit target, ফিক্সড 0.01 →
   পরে 0.02 lot। Risk-based lot বাদ।
3. **v8.12** — $10 TP (ডলার হিসাব), 50-pip SL, ২-মিনিট duration guard, BE@30pip, loss→stop /
   BE→retry লজিক (OnTradeTransaction দিয়ে)।
4. **v8.12 (pip fix)** — Gold-এ pip হিসাব ভুল ছিল (SL মাত্র 5 pips হচ্ছিল)। SL ডলার-ভিত্তিক করা হলো।
5. **v8.12 (dollar SL)** — SL ও TP একই ডলার-ভিত্তিক ফর্মুলায়।
6. **v8.13/v8.14** — Gold tick_value floating সমস্যা ধরা পড়ল। ব্রোকার TP/SL বাদ দিয়ে EA নিজে
   ডলার-প্রফিট দেখে ম্যানুয়ালি ক্লোজ করার approach। loss detection = position count + balance change।
7. **v8.15/v8.17** — `g_prevBalance` প্রতি টিকে আপডেট হওয়ার bug ধরা পড়ল (loss detection কাজ করছিল না)।
   Fix করা হলো, emergency SL 300→100, max trades 3→2।
8. **v8.18** — **সম্পূর্ণ রিরাইট: State Machine** (LOOKING / ARMED / IN_TRADE / DONE_WIN /
   DONE_LOSS)। কার্যত দিনে ১টা ট্রেড। কোনো জটিল balance tracking নেই।
9. **v8.19 (সর্বশেষ, বর্তমান)** — v8.18 + **সময় ফিল্টার**: রাতভর/উইকেন্ড গ্যাপ লস আটকাতে —
   রাত ১০টায় force close, রাত ৮টার পরে নতুন ট্রেড নয়, সকাল ৮টার আগে নয়, শুক্রবার ট্রেড নয়।
   Emergency SL 30 points।

> **অমীমাংসিত:** v8.18 বা v8.19 ব্যবহারকারী শেষপর্যন্ত ব্যাকটেস্ট করে ফলাফল দেখাননি। v8.17 পর্যন্ত
> সব লসে শেষ হয়েছিল।

---

## ৬. DATA — ব্যাকটেস্ট ফলাফল (স্ক্রিনশট থেকে, সৎভাবে)

সব ব্যাকটেস্ট: **XAUUSD, M5, 2026.01.01 → 2026.01.31**, MetaQuotes-Demo।

### ব্যাকটেস্ট A — v8.12 (early), Deposit $5,000:
- Gross Profit: **+$1,291.13**
- Gross Loss: **−$2,035.42**
- **Net: প্রায় −$744** (নেট লস)। *(আমি চ্যাটে একবার ভুলভাবে "Total Net Profit $5000 ডাবল"
  বলেছিলাম — সেটা misread ছিল; আসল ছবিতে Initial Deposit 5000 আর net ফল লস। এই অনিশ্চয়তা সৎভাবে
  উল্লেখ করছি।)*
- **Profit Factor: 0.63** (< 1 = লসে)
- Total Trades: **141** (সব long/BUY)
- **Win rate: 83.69%** (118 win / 23 loss)
- Largest profit trade: $32.52; Largest loss trade: −$102.85 (⚠️ বিশাল লস)
- Avg profit trade: $10.94; Avg loss trade: −$88.50
- Max consecutive wins: 26; Max consecutive losses: 2
- **Balance Drawdown Max: 18.45% ($962.87)**
- **Equity Drawdown Max: 19.11% ($997.09)** ⚠️ GFT limit 6% — অর্থাৎ বহুবার breach হতো
- Margin Level: 1389.61%

### ব্যাকটেস্ট B — v8.12 (dollar SL), Deposit $1,000:
- Balance শেষে: **$924.82**, Profit: **−$75.18** (নেট লস)
- একই দিনে একাধিক লস দেখা গেছে (loss→stop কাজ করছিল না)।
- লস ট্রেড: −$17.10, −$17.08, −$18.02, −$18.46 (উইন +$10, কিন্তু লস ~$17-18)
- একটা trade −$90.06 (রাতভর ওপেন → গ্যাপ; entry 4465.29 → close 4420.26)।

### ব্যাকটেস্ট C — v8.15, Deposit $1,000:
- Balance: **$957.82**, Profit: **−$42.18**
- একটি trade −$42.18 (emergency SL 300pt হিট: entry 5430.27, SL 5130.27)।
- TP/SL $10 কিছু ট্রেডে ঠিক কাজ করছিল (−$10.04, −$10.60, +$10.42, BE −$0.12)।

### ব্যাকটেস্ট D — v8.17, Deposit $1,000:
- Balance: **$968.58**, Profit: **−$31.42**
- 01.29-এ লসের পরেও আবার ট্রেড (loss→stop তখনও পুরোপুরি কাজ করছিল না)।
- একটা trade −$31.42 (emergency SL হিট, রাতভর/গ্যাপ)।

**সারমর্ম:** সব ব্যাকটেস্ট নেট লসে। মূল সমস্যা — win $10, কিন্তু loss $17-$90। উচ্চ win rate
সত্ত্বেও asymmetric loss-এ অ্যাকাউন্ট ক্ষয় হচ্ছিল, এবং drawdown GFT 6% limit বহুগুণ ছাড়াচ্ছিল।

---

## ৭. WARNINGS — বাগ, ভুল, এবং যা ভবিষ্যৎ এজেন্টকে অবশ্যই জানতে হবে

1. **⭐ Gold tick_value ফ্লোটিং (সব সমস্যার মূল):** XAUUSD-এ `SYMBOL_TRADE_TICK_VALUE` দামের সাথে
   বদলায়। এন্ট্রির সময় হিসাব করা "price distance" পরে ভিন্ন ডলার মান দেয়। এজন্য price-distance
   ভিত্তিক SL/TP অনির্ভরযোগ্য। **সমাধান দিক:** সবসময় live `PositionGetDouble(POSITION_PROFIT)`
   (আসল ডলার) দেখে ম্যানুয়ালি ক্লোজ করা — v8.18/v8.19 এই approach নিয়েছে, কিন্তু ব্যাকটেস্টে
   চূড়ান্তভাবে verify হয়নি।
2. **`g_prevBalance` bug (v8.14-v8.15):** প্রতি টিকে balance আপডেট হচ্ছিল, তাই ট্রেড ক্লোজে
   pnl সবসময় ~0 দেখাত → loss detection ব্যর্থ → একই দিনে বারবার লস। v8.15+ এ fix করা হয়েছে
   (শুধু position count বদলালে আপডেট)। v8.18 state machine এই সমস্যা এড়ায়।
3. **রাতভর/উইকেন্ড গ্যাপ:** trade রাতভর ওপেন থাকলে সকালের গ্যাপে EA -$10 এ ক্লোজ করতে পারে না →
   −$30 থেকে −$90 লস। v8.19-এ time filter (22:00 force close, শুক্রবার বন্ধ) যোগ করা হয়েছে।
4. **Emergency SL:** যেহেতু EA ম্যানুয়ালি ক্লোজ করে, ব্রোকারে শুধু একটা wide emergency SL থাকে।
   এটা 300→100→30 points করা হয়েছে। খুব টাইট (30pt) করলে EA ম্যানুয়াল ক্লোজের আগেই ব্রোকার SL
   ফায়ার করতে পারে — এটা যাচাই করা হয়নি।
5. **OnTradeTransaction অনির্ভরযোগ্য Strategy Tester-এ** — এজন্য বাদ দেওয়া হয়েছে।
6. **Long-only:** শুধু BUY। downtrend-এ কোনো সুযোগ নেয় না। ২৮ দিনে ৩ valid day + $100 করা কঠিন
   হতে পারে।
7. **⭐ Strategy-র edge অপ্রমাণিত:** সবচেয়ে বড় সতর্কতা — এই EA-র positive expectancy আছে এমন
   কোনো প্রমাণ নেই। সব ব্যাকটেস্ট লসে। RR 1:1 এ 83% win rate থাকলেও নেট লস মানে বড় লসগুলোই
   সমস্যা; কিন্তু বড় লস ঠিক করলেও strategy আদৌ লাভ দেবে কিনা অজানা।
8. **ফাইলের নাম বিভ্রান্তিকর:** নাম `v8.12` কিন্তু কোড `v8.19`। ব্যবহারকারী কয়েকবার পুরনো
   কম্পাইলড ভার্সন চালিয়ে ফেলেছিলেন — সবসময় chart title bar-এ version নম্বর চেক করা দরকার।
9. **Deposit ভুল:** ব্যবহারকারী একবার $5,000 দিয়ে টেস্ট করেছিলেন — আসল GFT অ্যাকাউন্ট $1,000,
   তাই DD% বেশি ভয়ঙ্কর। সবসময় $1,000 + 1:20 দিয়ে টেস্ট করতে হবে।

---

## ৮. ব্যবহারকারীর নির্দেশ / পছন্দ (মনে রাখতে হবে)

- **সব যোগাযোগ বাংলায়** করতে হবে।
- GFT Goat $1 rules **কঠোরভাবে** মানতে হবে (বিশেষত ২% floating, 6% trailing DD, ২-মিনিট রুল,
  no HFT/martingale/hedging)।
- লক্ষ্য: **প্রতিদিন $10, দিনে সাধারণত ১টি ট্রেড**, লস হলে সেদিন বন্ধ, $10 হলে সেদিন বন্ধ।
- **ফিক্সড 0.02 lot**, TP/SL ডলার-ভিত্তিক।
- **প্রতি version নতুন করে save + GitHub-এ push** করে link দিতে হবে (ব্যবহারকারীর filesystem
  access নেই, তিনি GitHub raw থেকে কপি করেন)।
- সময় সীমিত: **১৫-১৮ দিনে $100** করতে হবে (মানসিক চাপে আছেন, হতাশ)।
- Evidence সংরক্ষণ করতে বলা হয়েছে (chat, source versions, backtest reports) payout-এর জন্য।

---

## ৯. UNFINISHED WORK / পরবর্তী ধাপ

1. **v8.19 ব্যাকটেস্ট verify করা হয়নি** — এটাই প্রথম কাজ ($1000, 1:20, XAUUSD, M15, ২+ সপ্তাহ)।
   দেখতে হবে: (a) loss হলে সত্যিই দিন বন্ধ হয়, (b) কোনো লস $10-এর বেশি হয় না, (c) কোনো ট্রেড
   রাতভর থাকে না।
2. **Strategy edge যাচাই** — শুধু bug fix নয়; knee-pattern long-only আদৌ profitable কিনা তা
   একটা lot-independent expectancy test দিয়ে দেখা দরকার। না হলে EA কখনো $100 করতে পারবে না।
3. **RR পুনর্বিবেচনা** — 1:1 এ 83% win rate সত্ত্বেও নেট লস; বড় লস ঠিক হলে এটা বদলাতে পারে,
   কিন্তু হয়তো RR 1:1.5/1:2 দরকার।
4. **M15 নিশ্চিত করা** — ২-মিনিট রুল নিরাপদে মানার জন্য M5 নয়, M15 ভালো।
5. **সম্ভবত short/SELL লজিক যোগ** — ২৮ দিনে যথেষ্ট সুযোগ পেতে।

---

## ১০. সর্বশেষ সম্পূর্ণ সোর্স কোড — `CK_GFT_Fast_v8.12_GOAT1.mq5` (কোড ভিতরে v8.19)

> এটি এই সেশনের সর্বশেষ ও চূড়ান্ত ভার্সন (state machine + time filter)। এটি
> `goat1-v812-fixed-sl-tp` ব্রাঞ্চে push করা ছিল। নিচে সম্পূর্ণ, কোনো কাটছাঁট ছাড়া।

```mql5
//+------------------------------------------------------------------+
//|                                    CK GFT Fast v8.19 FINAL      |
//|   NO OVERNIGHT TRADES - Auto close before market close           |
//|   ONE TRADE PER DAY. Win=$10, Loss=$10. DONE.                    |
//+------------------------------------------------------------------+
#property copyright "CK GFT Fast"
#property version   "8.19"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//--- Inputs
input long   InpMagic             = 20260715;
input double InpFixedLot          = 0.02;
input double InpTPDollars         = 10.0;
input double InpSLDollars         = 10.0;
input double InpBEDollars         = 6.0;
input double InpFloatingLossMax   = 1.8;
input int    InpMinTradeDuration  = 120;
input int    InpMaxSpreadPoints   = 50;
input bool   InpUseTrend          = true;
input int    InpEMAPeriod         = 21;
input int    InpEMASlow           = 50;
input int    InpKneeMinRun        = 2;
input int    InpValidBars         = 5;

// TIME FILTERS - Broker server time
input int    InpTradeStartHour    = 8;           // Don't trade before this hour
input int    InpTradeStopHour     = 20;          // Don't OPEN new trades after this
input int    InpForceCloseHour    = 22;          // FORCE close all trades at this hour
input bool   InpNoFriday          = true;        // No trading on Friday

//--- State
enum ENUM_DAY_STATE
{
   STATE_LOOKING,
   STATE_ARMED,
   STATE_IN_TRADE,
   STATE_DONE_WIN,
   STATE_DONE_LOSS
};

int      atrHandle, emaFastHandle, emaSlowHandle;
datetime lastBarTime  = 0;
datetime g_dayStart   = 0;
ENUM_DAY_STATE g_state = STATE_LOOKING;
double   g_trigger    = 0.0;
int      g_barsLeft   = 0;
bool     g_beApplied  = false;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   atrHandle     = iATR(_Symbol, _Period, 14);
   emaFastHandle = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, _Period, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   if(atrHandle==INVALID_HANDLE || emaFastHandle==INVALID_HANDLE || emaSlowHandle==INVALID_HANDLE)
      return(INIT_FAILED);
   g_dayStart = iTime(_Symbol, PERIOD_D1, 0);
   g_state = STATE_LOOKING;
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(atrHandle!=INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(emaFastHandle!=INVALID_HANDLE) IndicatorRelease(emaFastHandle);
   if(emaSlowHandle!=INVALID_HANDLE) IndicatorRelease(emaSlowHandle);
}

//+------------------------------------------------------------------+
double EMAFast(int s) { double b[]; if(CopyBuffer(emaFastHandle,0,s,1,b)<=0) return(0); return(b[0]); }
double EMASlow(int s) { double b[]; if(CopyBuffer(emaSlowHandle,0,s,1,b)<=0) return(0); return(b[0]); }
bool IsNewBar() { datetime t=iTime(_Symbol,_Period,0); if(t!=lastBarTime){lastBarTime=t;return(true);} return(false); }
bool IsGreen(int s) { return(iClose(_Symbol,_Period,s)>iOpen(_Symbol,_Period,s)); }
bool IsRed(int s)   { return(iClose(_Symbol,_Period,s)<iOpen(_Symbol,_Period,s)); }
bool IsTrendBuy() { return(EMAFast(1)>EMASlow(1) && iClose(_Symbol,_Period,1)>EMAFast(1)); }

//+------------------------------------------------------------------+
//| Time helpers                                                      |
//+------------------------------------------------------------------+
int CurrentHour()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return(dt.hour);
}

int CurrentDayOfWeek()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return(dt.day_of_week);
}

bool IsGoodTimeToTrade()
{
   int hour = CurrentHour();
   int dow  = CurrentDayOfWeek();

   // No Sunday
   if(dow == 0) return(false);
   // No Friday if enabled
   if(InpNoFriday && dow == 5) return(false);
   // Only during trading window
   if(hour < InpTradeStartHour) return(false);
   if(hour >= InpTradeStopHour) return(false);
   return(true);
}

bool IsForceCloseTime()
{
   int hour = CurrentHour();
   return(hour >= InpForceCloseHour);
}

//+------------------------------------------------------------------+
//| Position helpers                                                  |
//+------------------------------------------------------------------+
double GetProfit()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      return(PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP));
   }
   return(0);
}

int GetElapsed()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      return((int)(TimeCurrent() - (datetime)PositionGetInteger(POSITION_TIME)));
   }
   return(0);
}

bool HasPosition()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)==InpMagic && PositionGetString(POSITION_SYMBOL)==_Symbol)
         return(true);
   }
   return(false);
}

void ClosePosition()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      trade.PositionClose(tk);
   }
}

void MoveSLtoEntry()
{
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk=PositionGetTicket(i); if(tk==0) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double be=NormalizeDouble(open,dg);
      trade.PositionModify(tk, be, 0);
   }
}

//+------------------------------------------------------------------+
//| MAIN TICK                                                         |
//+------------------------------------------------------------------+
void OnTick()
{
   // NEW DAY - reset state
   if(iTime(_Symbol, PERIOD_D1, 0) != g_dayStart)
   {
      g_dayStart = iTime(_Symbol, PERIOD_D1, 0);
      if(!HasPosition())
         g_state = STATE_LOOKING;
   }

   // FORCE CLOSE at 22:00 - NO OVERNIGHT TRADES!
   if(HasPosition() && IsForceCloseTime())
   {
      double p = GetProfit();
      ClosePosition();
      Print("*** FORCE CLOSE (end of day): $", DoubleToString(p,2), " ***");
      if(p < -1.0) g_state = STATE_DONE_LOSS;
      else if(p > 1.0) g_state = STATE_DONE_WIN;
      else g_state = STATE_DONE_LOSS;  // treat BE as done too
      return;
   }

   // If DONE - nothing else
   if(g_state == STATE_DONE_WIN || g_state == STATE_DONE_LOSS)
      return;

   // STATE_IN_TRADE - manage
   if(g_state == STATE_IN_TRADE)
   {
      if(!HasPosition())
      {
         // Broker closed it (SL/gap)
         g_state = STATE_DONE_LOSS;
         Print("*** POSITION GONE - DONE ***");
         return;
      }

      double profit = GetProfit();
      int elapsed = GetElapsed();

      // LOSS - close at -$10
      if(profit <= -InpSLDollars)
      {
         ClosePosition();
         g_state = STATE_DONE_LOSS;
         Print("*** SL: $", DoubleToString(profit,2), " - DONE ***");
         return;
      }

      // WIN - close at +$10 after 2 min
      if(profit >= InpTPDollars && elapsed >= InpMinTradeDuration)
      {
         ClosePosition();
         g_state = STATE_DONE_WIN;
         Print("*** TP: $", DoubleToString(profit,2), " - DONE ***");
         return;
      }

      // BE - move SL to entry at +$6
      if(profit >= InpBEDollars && !g_beApplied)
      {
         MoveSLtoEntry();
         g_beApplied = true;
         Print("*** BE at $", DoubleToString(profit,2), " ***");
      }

      // Floating guard
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      if(bal > 0 && profit <= -(bal * InpFloatingLossMax / 100.0))
      {
         ClosePosition();
         g_state = STATE_DONE_LOSS;
         Print("*** FLOATING GUARD: $", DoubleToString(profit,2), " ***");
         return;
      }
      return;
   }

   // Below: LOOKING or ARMED - need good time to trade
   if(!IsGoodTimeToTrade()) return;

   // STATE_ARMED - wait for trigger
   if(g_state == STATE_ARMED)
   {
      if(IsNewBar())
      {
         g_barsLeft--;
         if(g_barsLeft <= 0)
         {
            g_state = STATE_LOOKING;
            return;
         }
      }

      if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD) > InpMaxSpreadPoints) return;

      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask >= g_trigger)
      {
         // OPEN TRADE - tight emergency SL (30 points, ~$6 max)
         int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
         double emergSL = NormalizeDouble(ask - 30.0, dg);

         trade.Buy(InpFixedLot, _Symbol, 0, emergSL, 0);
         g_state = STATE_IN_TRADE;
         g_beApplied = false;
         Print("*** OPEN @ ", DoubleToString(ask,dg), " ***");
      }
      return;
   }

   // STATE_LOOKING
   if(g_state == STATE_LOOKING)
   {
      if(IsNewBar())
      {
         if(IsRed(1))
         {
            int run=0;
            for(int i=2; i<=12; i++) { if(IsGreen(i)) run++; else break; }
            bool trendOK = (!InpUseTrend) || IsTrendBuy();
            if(run >= InpKneeMinRun && trendOK)
            {
               g_trigger  = iHigh(_Symbol, _Period, 1);
               g_barsLeft = InpValidBars;
               g_state    = STATE_ARMED;
               Print("*** ARMED @ ", DoubleToString(g_trigger,2), " ***");
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
```

---

## ১১. রিকভারি নির্দেশিকা (ভবিষ্যৎ এজেন্টের জন্য)

- সর্বশেষ কোড দুই জায়গায়: (a) এই ডকুমেন্টের সেকশন ১০, (b) ব্রাঞ্চ `goat1-v812-fixed-sl-tp`-এ
  `CK_GFT_Fast_v8.12_GOAT1.mq5`।
- `main` ব্রাঞ্চে থাকা `CK_GFT_Fast_v8.12_GOAT1.mq5` একটি **পুরনো (10KB) ভার্সন** — বিভ্রান্ত হবেন না।
- প্রথম কাজ: v8.19 ব্যাকটেস্ট ($1000/1:20/M15) করে 3টি জিনিস verify — loss→day stop, কোনো লস
  $10-এর বেশি নয়, কোনো overnight trade নেই।
- এরপর strategy-র edge আছে কিনা নিরপেক্ষভাবে যাচাই করুন। **edge না থাকলে কোনো tuning কাজে দেবে না।**

---

*(এই ডকুমেন্ট সৎভাবে লেখা হয়েছে। কোনো ফলাফল বানানো হয়নি। ব্যাকটেস্ট সংখ্যাগুলো ব্যবহারকারীর
পাঠানো স্ক্রিনশট থেকে পড়া — ঝাপসা ছবির কারণে সামান্য পড়ার ভুল সম্ভব; মূল উপসংহার — সব ব্যাকটেস্ট
নেট লসে — নিশ্চিত।)*
