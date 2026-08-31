# POC_VA — শৃঙ্খলিত একক চেষ্টা: Diagnosis + Session-filter টেস্ট (বাংলা)

- সিমুলেটর: MetaTrader 5 Strategy Tester, real ticks — একমাত্র সত্যের উৎস
- deposit $50,000 (margin আটকায় না), leverage 1:10, XAUUSD M15, সব input pinned (GUARD #20)
- মূল ফাইল `CK_POC_VA_v1.mq5` **অপরিবর্তিত**; filter টেস্টের জন্য আলাদা `CK_POC_VA_SESS.mq5` (শুধু session-gate যোগ, signal/sizing অপরিবর্তিত)
- ledger: SPEC/dof_ledger.jsonl seq 85–89 (hash-chain verified, ৮৯ রেকর্ড OK)
- **চূড়ান্ত রায়: কোনো robust edge নেই — থামলাম।**

## ধাপ ১ — Diagnosis (কিছু বদলানো হয়নি; বিদ্যমান MT5 ফল থেকে)

session অনুযায়ী per-trade expectancy (দুই current-regime অর্ধ + OOS):

| session | cr_h1 | cr_h2 | OOS | সঙ্গতি |
|---|---|---|---|---|
| Asia (0-8) | −$29 | −$15 | −$21 | ধারাবাহিক লোকসানি |
| London (8-13) | +$60 | −$21 | +$3 | অসঙ্গত |
| LDN_NY (13-17) | −$16 | +$43 | +$19 | অসঙ্গত |
| NY_late (17-24) | +$135 | +$84 | +$83 | তিনটাতেই শক্তিশালী |

CSV-filter করে দেখা গেল: NY_late (17-24) ও US-session (13-24) তিন উইন্ডোতেই PF>1 এবং $৫ খরচের অনেক উপরে — মনে হলো তিন শর্তই পাস। তাই একটা structural session-filter টেস্ট করার শর্ত পূরণ হলো।

**সতর্কতা (যা আগেই লিখেছিলাম):** CSV-filter ≠ বাস্তব session-gated রান — কারণ daily trade-cap ও one-position নিয়ম interaction করে। তাই authoritative হতে বাস্তব MT5 রান দরকার।

## ধাপ ২ — Session-filter টেস্ট (বাস্তব MT5, pre-registered)

দুটি pinned-hour filter টেস্ট করা হলো (কোনো optimize নয়):

| Filter | IS PF | OOS PF | OOS exp | cr_h1 PF | cr_h2 PF | রায় |
|---|---|---|---|---|---|---|
| US session 13-24 (primary) | 1.06 | **0.88** | −$12 | 1.01 | **0.88** | **REJECT** |
| NY_late 17-24 (secondary) | 0.93 | **0.74** | −$29 | — | — | **REJECT** |

**দুটোই বাস্তব রানে লোকসানি (OOS PF < 1)।**

## কেন CSV-filter ভুল দেখিয়েছিল (মূল শিক্ষা)

EA-কে সত্যিই ১৩-২৪ (বা ১৭-২৪)-এ সীমাবদ্ধ করলে daily trade-cap খালি হয়ে যায়, তাই EA **আরও বেশি** ওই-ঘণ্টার setup নেয় (OOS: ১৪৫ → ৩৪১ ট্রেড)। সেই অতিরিক্ত ট্রেডগুলো লোকসানি। অর্থাৎ আগের রানে ওই ঘণ্টাগুলোতে যে অল্প কিছু ট্রেড লাভজনক দেখাচ্ছিল, সেটা ছিল daily-cap-এর কারণে **কোন ট্রেডগুলো ঘটেছিল তার একটা selection বিভ্রম** — সত্যিকারের time-of-day edge নয়।

এটাই master prompt-এর সতর্কবার্তার জীবন্ত প্রমাণ: **MT5-ই সত্যের উৎস; Python-filter দিয়ে বিশ্লেষণ একটা কাল্পনিক edge বানিয়ে ফেলতে পারে।**

## তিন শর্তের বিচার (একসাথে)

1. per-trade edge >> $৫ খরচ: ❌ (বাস্তবে OOS expectancy ঋণাত্মক)
2. current-regime দুই অর্ধেই PF>1: ❌ (cr_h2 PF 0.88)
3. OOS টেকে: ❌ (OOS PF 0.88 / 0.74, লোকসানি)

**তিনটির একটিও বাস্তব রানে পাস করেনি → থামলাম।**

## চূড়ান্ত সিদ্ধান্ত

- POC_VA **consistent কিন্তু পাতলা** — এবং এর ভেতরে কোনো exploitable structural sub-edge (session) নেই; আপাত edge ছিল artifact।
- আর কোনো টিউনিং করা হবে না (overfit নিষিদ্ধ)।
- **পুরো প্রজেক্ট জুড়ে সৎ উপসংহার: repo-র কোনো strategy এখন robust, current, খরচ-সহনশীল edge দেখায় না।**
- আসল টাকা / লাইভ: আপনার অনুমতি ছাড়া কিছু করা হয়নি এবং হবে না।

---
*সব ট্রেড সিমুলেশন MT5-এ (real ticks); Python শুধু হিসাব। সব input pinned (GUARD #20); সব রান SPEC/dof_ledger.jsonl-এ hash-chain করা (seq 61–89, verified)। মূল EA ফাইলগুলো অপরিবর্তিত; session-gate শুধু আলাদা পরীক্ষামূলক ফাইলে।*
