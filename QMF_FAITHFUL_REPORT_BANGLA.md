# Faithful QM/ICT EA — MT5 টেস্ট রিপোর্ট (বাংলা)

- EA: **CK_QM_ICT_FAITHFUL_v1.mq5** — SPEC/QM_ICT_STRATEGY_SPEC.md থেকে নতুন করে বানানো (পুরনো simplified CK_QM_ICT_EA নয়)
- সিমুলেটর: MT5 Strategy Tester, real ticks (Model 4) — একমাত্র সত্যের উৎস; Python শুধু হিসাব
- deposit **$50,000** (margin আটকায় না), leverage 1:10, XAUUSD M15, **সব ২৭টি input pinned** (GUARD #20)
- সম্পূর্ণ causal chain: swings(M15) → head raids left-shoulder → MSS down (body-close < neckline + displacement) → IDM cleared → QM/POI-তে return → M5 rejection → break-এ entry, SL=rejection extreme+buffer, TP=opposite external liquidity, projected-RR গেট
- ledger: SPEC/dof_ledger.jsonl (এই কাজের এন্ট্রি সহ, hash-chain verified)

## গুরুত্বপূর্ণ: চেইন সত্যিই কাজ করছে (faithfulness যাচাই)
প্রথম বিল্ডে OnTester funnel দেখাল `MSS=1325` কিন্তু `IDM=0` — অর্থাৎ চেইন IDM-এ আটকে ছিল। কারণ ধরা পড়ল: geometry-র সময়ক্রম ভুল (head-কে সবচেয়ে সাম্প্রতিক ধরেছিলাম, কিন্তু QM-এ head আসে MSS-এর আগে, retrace/IDM আসে পরে)। ঠিক করে **MSS anchor করে পেছনে head+shoulder, সামনে IDM+retrace** — এরপর চেইন ঠিকমতো entry পর্যন্ত ফায়ার করল (silent-zero বাগ নয়)।

## ফলাফল

| variant | উইন্ডো | ট্রেড | PF | exp/ট্রেড | রায়-নির্দেশক |
|---|---|---|---|---|---|
| **SMT off** | IS (জুন–ডিসে ২০২৫) | 69 | 2.15 | +$47 | শক্তিশালী |
| | OOS (ডিসে ২০২৫–আগ ২০২৬) | 149 | **0.53** | −$43 | তীব্র লোকসান |
| | cr_h1 | 61 | 1.47 | +$41 | লাভ |
| | cr_h2 | 94 | **0.48** | −$47 | লোকসান |
| **SMT on** | IS | 31 | 3.06 | +$95 | শক্তিশালী (ছোট n) |
| | OOS | 60 | **0.83** | −$12 | লোকসান (কম) |
| | cr_h1 | 41 | **0.57** | −$31 | লোকসান |
| | cr_h2 | 34 | 1.14 | +$10 | সামান্য লাভ |

## তিন শর্তের বিচার (একসাথে)

| শর্ত | SMT off | SMT on |
|---|---|---|
| শর্ত | SMT off | SMT on | POI3 (QM+OB/FVG, SMT on) |
|---|---|---|---|
| ১) OOS edge (PF>1, খরচ-সহনশীল) | ❌ PF 0.53 | ❌ PF 0.83 | ❌ PF 0.83 |
| ২) current-regime দুই অর্ধেই PF>1 | ❌ (cr_h2 0.48) | ❌ (cr_h1 0.57) | ❌ (cr_h1 0.57) |
| ৩) IS→OOS ধস নেই | ❌ 2.15→0.53 | ❌ 3.06→0.83 | ❌ 3.06→0.83 |

**তিনটি variant-এর একটিও তিন শর্ত একসাথে পাস করেনি।**

### শেষ variant — POI confluence (QM + OB/FVG), SMT=on
spec §4 অনুযায়ী OB/FVG confluence লজিক সত্যিকারভাবে যোগ করা হলো (আগে শুধু ঘোষিত ছিল, কোড ছিল না — সৎভাবে জানানো হয়েছিল)। ফল **SMT-on-এর হুবহু সমান** (IS 31, OOS 60, cr_h1 41, cr_h2 34)। কারণ: QM left-shoulder POI-তে প্রায় সবসময়ই একটা OB বা FVG থাকে (shoulder+displacement স্বাভাবিকভাবেই তৈরি করে), তাই confluence গেটটা **non-binding** — কিছুই ফিল্টার করে না। অর্থাৎ এই structural variant edge বদলায় না।

## সৎ পর্যবেক্ষণ

- **IS খুব শক্তিশালী** (PF ২.১৫ / ৩.০৬) কিন্তু **OOS-এ ভেঙে পড়ে** — এটা low-winrate/high-RR setup; IS-এ কিছু বড় winner (avg_win $৪৬৬–১১৩৪), OOS-এ win rate ৮–১২%-এ নেমে বেরিয়ে যায়।
- **SMT সাহায্য করে** (দিকনির্দেশক): OOS PF ০.৫৩→০.৮৩, ট্রেড ১৪৯→৬০ (বেশি selective, কম খরচ-এক্সপোজার)। কিন্তু robust edge-এ পৌঁছায় না — OOS এখনো লোকসানি।
- **স্যাম্পল ছোট** (SMT-on OOS মাত্র ৬০, অর্ধগুলো ৩৪–৪১) — statistically দুর্বল, ২০০-র বার ছোঁয় না। এটাই এই setup-এর একটা বাস্তব সীমা (কম কিন্তু নির্বাচিত ট্রেড)।
- current regime-এ **কোনো অর্ধ সবসময় লোকসানি** — edge ধারাবাহিক নয়।

## রায় ও সীমাবদ্ধতা (সততা)

- **রায়: এই মুহূর্তে faithful QM/ICT robust, current edge দেখায় না** (দুই variant-ই OOS-এ লোকসানি + অর্ধ-অসঙ্গত)। spec §10 যেমন বলেছিল — একটা পরিষ্কার "no robust edge" সৎ ও বৈধ উত্তর।
- **সীমাবদ্ধতা (স্বীকার করছি):**
  1. এটা spec-এর আমার **faithful ব্যাখ্যা** — POI zone সংজ্ঞা, IDM logic, TP=external-low ইত্যাদিতে বাস্তবায়ন-সিদ্ধান্ত আছে; creator-এর হুবহু হাতে-আঁকা ইচ্ছার সাথে ছোট পার্থক্য থাকতে পারে।
  2. POI-confluence (QM+OB/FVG) variant এখন A/B করা হয়েছে — non-binding, ফল বদলায়নি। বাকি structural variant (TP=fixed_rr, erl_tf=H4) A/B করা হয়নি; OOS যেহেতু তিন variant-এই লোকসানি, এগুলো থেকে robust edge আসার আশা কম।
  3. স্যাম্পল ছোট — আরও ইতিহাস (real-tick শুধু 2025.05.27+) থাকলে বিচার আরও শক্ত হতো।
- **কোনো টিউনিং করিনি** (লোকসানি edge টিউন করা = overfit, নিষিদ্ধ)।
- **আসল টাকা/লাইভ:** কিছু করা হয়নি, আপনার অনুমতি ছাড়া হবে না।

## পরের সৎ পথ (গবেষণা, টাকা নয়)
- চাইলে ১টা structural variant A/B (যেমন POI+OB confluence, বা erl_tf=H4) — pre-register করে, একই ৩ শর্তে বিচার। কিন্তু OOS লোকসানি হওয়ায় প্রত্যাশা কম রাখুন।
- অথবা "faithful QM/ICT-ও এই ডেটায় robust edge দেয় না" — এটাকেই সৎ, প্রমাণভিত্তিক ফলাফল হিসেবে গ্রহণ করা।

---
*সব ট্রেড MT5-এ (real ticks); Python শুধু হিসাব। সব input pinned (GUARD #20); সব রান hash-chained ledger-এ। EA চেইন funnel-counter দিয়ে যাচাই করা হয়েছে যে এটা সত্যিই ধাপে ধাপে কাজ করছে।*


---

## চূড়ান্ত সিল (৩ variant শেষে)

তিনটি faithful variant (SMT-off, SMT-on, QM+OB/FVG+SMT) MT5-এ পরীক্ষা করা হয়েছে — deposit 50k, সব input pinned, real ticks, current-regime দুই অর্ধ + IS/OOS + cost stress। **কোনোটিই তিন শর্ত একসাথে পাস করেনি:**
- OOS সবসময় লোকসানি (PF 0.53 / 0.83 / 0.83)
- current regime-এর কোনো একটি অর্ধ সবসময় লোকসানি (ধারাবাহিক নয়)
- IS→OOS-এ তীব্র ধস (PF ~3 → <1)

**চূড়ান্ত সৎ রায়: faithful QM/ICT এই XAUUSD real-tick ডেটায় robust, current, খরচ-সহনশীল edge দেয় না।** এটাই প্রমাণভিত্তিক সত্য — spec §10 যেমন স্বীকৃতি দিয়েছিল, একটা পরিষ্কার "no robust edge" বৈধ ও মূল্যবান উত্তর, বানানো edge নয়। কোনো টিউনিং করা হয়নি; কোনো লাইভ/আসল-টাকা পদক্ষেপ নেওয়া হয়নি।

এটা পুরো প্রজেক্টের সামগ্রিক ফলাফলের সাথেও সঙ্গতিপূর্ণ: repo-র কোনো strategy (trend family, POC_VA, QM/ICT) এখন robust current edge দেখায় না। আসল deliverable = এই সৎ, reproducible, MT5-only যাচাই-ল্যাব ও tamper-evident ledger।
