# চূড়ান্ত সারাংশ রিপোর্ট (বাংলা) — XAUUSD Strategy Validation Lab

> Boss-কে দেখানোর জন্য। উদ্দেশ্য ছিল ব্যাকটেস্ট-লাভ সর্বোচ্চ করা নয় — বরং কৌশলগুলোকে
> নিরপেক্ষভাবে **যাচাই ও আক্রমণ (attack)** করে overfit/বিভ্রম ধরে ফেলা। "কোনো robust edge নেই"
> — এটাও একটা সৎ ও বৈধ উত্তর।

- সিমুলেটর: **MetaTrader 5 Strategy Tester, real ticks (Model 4)** — একমাত্র সত্যের উৎস
- Python শুধু MT5-এর আউটপুট বিশ্লেষণ করেছে (কখনো ট্রেড সিমুলেট করেনি)
- প্রতিটা রানে EA-র **সব input pinned** (GUARD #20); সব সিদ্ধান্ত hash-chained ledger-এ (SPEC/dof_ledger.jsonl, seq 61–89, verified)
- Symbol: XAUUSD · TF: M15 · edge মাপা হয়েছে deposit $50,000-এ (margin-wall এড়াতে), leverage 1:10 (deployed)
- কোনো strategy টিউন/optimize করা হয়নি (overfit নিষিদ্ধ)

---

## ১. এক নজরে — কোন strategy কী রায় পেল

| # | Strategy | ধরন | মূল ফল | রায় |
|---|---|---|---|---|
| 1 | CK_GOLD_PRO_FIX09 | trend (fixed 0.09 lot) | IS PF 1.98 → OOS PF 1.13; cr_h2 লোকসানি | **REJECT** |
| 2 | CK_GFT_Fast_v23_ROBUST | trend (risk-based lot) | 50k-এ 0.09 cap → কার্যত FIX09-এর সমান; একই ধস | **REJECT** |
| 3 | CK_POC_VA_v1 | volume-profile | দুই অর্ধেই PF>1 (consistent!) কিন্তু edge পাতলা; $5 খরচে মরে | **FAIL** |
| 4 | CK_QM_ICT_EA | ICT / Quasimodo | মাত্র 35 OOS ট্রেড; current-regime দুই অর্ধেই লোকসানি | **INSUFFICIENT / REJECT** |
| 5 | POC_VA + US-session 13-24 filter | structural filter | বাস্তব রানে OOS PF 0.88 (লোকসানি) | **REJECT** |
| 6 | POC_VA + NY_late 17-24 filter | structural filter | বাস্তব রানে OOS PF 0.74 (লোকসানি) | **REJECT** |

**সারমর্ম: এই মুহূর্তে repo-র কোনো strategy লাইভ-দেওয়ার মতো robust, current, খরচ-সহনশীল edge দেখায় না।**

---

## ২. দুই ধরনের ব্যর্থতা (কেন REJECT/FAIL)

**(ক) Trend family (FIX09, v23) — শক্তিশালী কিন্তু regime-নির্ভর:**
- পুরোনো ডেটায় (IS) PF ~2.0, কিন্তু অদেখা নতুন ডেটায় (OOS) PF ~1.1 — নিয়ম-ভিত্তিক পাইপলাইন একে "severe IS→OOS collapse (K3 killer)" বলে **REJECT** করেছে।
- সব লাভ মূলত **অক্টো ২০২৫–ফেব ২০২৬ গোল্ড বুল-স্পাইকে**; সাম্প্রতিক ৬ মাস (মার্চ–আগস্ট ২০২৬) নিট **লোকসান (−$৩,৪৫১)**।
- OOS-এর সেরা ১০টা ট্রেড বাদ দিলে বাকিটা লোকসানি — মানে edge কয়েকটা বড় ট্রেডে কেন্দ্রীভূত।

**(খ) POC_VA (volume-profile) — ধারাবাহিক কিন্তু অত্যন্ত পাতলা:**
- একমাত্র EA যেটা current-regime **দুই অর্ধেই PF>1** এবং IS→OOS ধস নেই — গঠনগতভাবে সবচেয়ে সৎ।
- কিন্তু per-trade লাভ মাত্র ~$৫, আর প্রচুর ট্রেড করে — তাই **মাত্র $৫/ট্রেড খরচেই লাভ শূন্য/ঋণাত্মক** (cost stress FAIL)। edge < খরচ → অচল।

**(গ) QM_ICT (ICT) — স্যাম্পল অপ্রতুল:** এত কম ট্রেড (OOS ৩৫) যে যাচাই অসম্ভব, আর current regime-এ লোকসানি।

---

## ৩. সবচেয়ে গুরুত্বপূর্ণ শিক্ষা — "Phantom edge" (কাল্পনিক edge)

POC_VA-র সবচেয়ে আশাব্যঞ্জক দিকটা ছিল: session-ভাঙা বিশ্লেষণে মনে হচ্ছিল **NY/US-সন্ধ্যায় (13-24) খুব শক্তিশালী edge** (per-trade $৪৫–১৩৫, দুই অর্ধ + OOS তিনটাতেই)। কিন্তু সেটা ছিল Python দিয়ে CSV **filter** করার ফল।

যখন EA-কে **সত্যিই** ওই ঘণ্টায় সীমাবদ্ধ করে MT5-এ চালানো হলো — ফল **উল্টো**: OOS PF ০.৮৮ ও ০.৭৪ (লোকসানি)।

**কারণ:** EA-র daily trade-cap আছে। Asia-ট্রেড বাদ দিলে cap খালি হয়ে EA **আরও বেশি** ওই-ঘণ্টার ট্রেড নেয় (OOS ১৪৫ → ৩৪১), আর সেই অতিরিক্ত ট্রেডগুলো লোকসানি। অর্থাৎ আপাত edge ছিল "কোন ট্রেডগুলো ঘটেছিল" তার একটা **selection বিভ্রম** — সত্যিকারের time-of-day edge নয়।

➡️ **শিক্ষা: MT5-ই সত্যের উৎস। Python-filter দিয়ে বিশ্লেষণ একটা কাল্পনিক edge বানিয়ে ফেলতে পারে।** আমাদের ল্যাব ঠিক এই ফাঁদটাই ধরে ফেলেছে — এটাই বানানো লাভের বিরুদ্ধে আসল সুরক্ষা।

---

## ৪. আরেকটি বড় আবিষ্কার — Margin-wall (মূলধন ঝুঁকি)

- গোল্ডের দাম এখন ~$৫,০০০। এই ব্রোকারে ০.০৯ লট গোল্ড খুলতে ~$৪,৯৫০ মার্জিন লাগে — $৫,০০০ অ্যাকাউন্টের প্রায় পুরোটা।
- এটা লিভারেজ-নির্ভর নয় (গোল্ডে ফিক্সড ~১০% মার্জিন; ১:১০ vs ১:১০০ — একই ফল, যাচাই করা হয়েছে)।
- ফলে $৫,০০০ দিয়ে শুরু করে সামান্য লস হলেই অ্যাকাউন্ট **নতুন ট্রেড খুলতে পারে না** ("No money") — একটা বাস্তব ডিপ্লয়মেন্ট ঝুঁকি।
- তাই edge মাপার সময় $৫০,০০০ deposit ব্যবহার করেছি (margin যাতে বিচার নষ্ট না করে); ডিপ্লয় ঝুঁকিটা আলাদাভাবে লেখা আছে।

---

## ৫. আসল Deliverable — এই honest, reproducible ল্যাব

কোনো "জাদুকরী EA" নয় — আসল সম্পদ হলো এই যাচাই-অবকাঠামো, যা যেকোনো ভবিষ্যৎ কৌশলে পুনঃব্যবহারযোগ্য:

- **`tools/detect_env.ps1`** — পরিবেশ auto-detect (কোনো hard-coded path নেই)
- **`tools/make_ini.ps1`** — GUARD #20: একটাও input বাদ পড়লে রান থামিয়ে দেয় (cache-drift বন্ধ)
- **`tools/run_candidate.ps1`** — এক কমান্ডে: compile → বহু-উইন্ডো real-tick MT5 রান → রিপোর্ট+CSV সংগ্রহ → deterministic verdict
- **`tools/edge_diagnose.py`, `filter_hours.py`, `monthly_breakdown.py`, `scan_log.py`** — বিশ্লেষণ
- **`v1_lab/pipeline.py`** — নিয়ম-ভিত্তিক PASS/FAIL/REJECT (K-killers, M1–M8, walk-forward, Monte-Carlo, cost stress); থ্রেশহোল্ড locked
- **`SPEC/dof_ledger.jsonl`** — প্রতিটা সিদ্ধান্ত hash-chained (tamper-evident), pre-registration সহ — ৮৯টি রেকর্ড, verified

**নীতি:** AI আবিষ্কার করে ও ব্যাখ্যা করে; deterministic কোড মাপে ও বিচার করে; unseen + forward ডেটাই চূড়ান্ত প্রমাণ; একক metric দিয়ে PASS নয়; overfitting নিষিদ্ধ।

---

## ৬. চূড়ান্ত রায় ও সৎ পরামর্শ

- **এই মুহূর্তে কোনো strategy লাইভ/আসল-টাকার যোগ্য নয়।** (যেকোনো লাইভ সিদ্ধান্তে মানুষের সুস্পষ্ট অনুমোদন লাগবেই।)
- boss-এর +৬০০%/বছর লক্ষ্য নিয়ন্ত্রিত ঝুঁকিতে বাস্তবসম্মত নয় (আগের রিপোর্টেও লেখা)।
- **সৎ পরের পথ (সব গবেষণা, কোনো টাকা নয়):**
  1. সম্পূর্ণ নতুন, স্বাধীনভাবে-যুক্তিসঙ্গত কোনো edge-ধারণা এই একই pipeline-এ পরীক্ষা — আগে থেকে pre-register করে; অথবা
  2. "কোনো robust edge নেই" মেনে নেওয়া এবং এই যাচাই-অবকাঠামো ও সততাকেই ফলাফল হিসেবে উপস্থাপন করা।

---
*সব ট্রেড সিমুলেশন MT5-এ (real ticks); Python শুধু হিসাব। সব input pinned (GUARD #20); প্রতিটা রান ও সিদ্ধান্ত SPEC/dof_ledger.jsonl-এ hash-chain করা (seq 61–89, verified)। বিস্তারিত: FIX09_VALIDATION_REPORT.md, MULTI_EA_VALIDATION_REPORT.md, POCVA_DIAGNOSIS_REPORT.md।*
