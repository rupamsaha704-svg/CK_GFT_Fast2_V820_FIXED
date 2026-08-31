# QM/ICT — Diagnosis + নিকটবর্তী-TP টেস্ট (বাংলা)

- সব MT5 Strategy Tester (real ticks); Python শুধু হিসাব। deposit $50k, সব input pinned (GUARD #20)।
- আগে **DIAGNOSE** (নতুন রান নয়, বিদ্যমান ফল থেকে), তারপর diagnosis-driven **creator-specified বিকল্প TP** টেস্ট।
- ledger: seq 96–101 (hash-chain verified)।

## অংশ ১ — DIAGNOSIS (বিদ্যমান QM/ICT MT5 ফল থেকে)

আমার EA কোনো position-management করে না — এন্ট্রিতে SL+TP বসিয়ে ছেড়ে দেয় — তাই প্রতিটা exit হয় **TP-hit (winner)** বা **SL-hit (loser)**। অর্থাৎ exit-profile = win rate নিজেই।

| | win rate | realized RR (avg_win/avg_loss) | breakeven winrate | ফল |
|---|---|---|---|---|
| SMT-off IS | 18.8% | 9.25 | 9.8% | উপরে (edge) |
| SMT-off OOS | **8.7%** | 5.53 | 15.3% | **নিচে (bleeds)** |
| SMT-on IS | 22.6% | 10.5 | 8.7% | উপরে (edge) |
| SMT-on OOS | **11.7%** | 6.30 | 13.7% | **নিচে (bleeds)** |

**রোগ নির্ণয়:** exit-এর ~৮৮–৯১% SL-hit; TP খুব দূরে (full-external → realized RR ৫.৫–৬.৩x)। এই low-winrate/high-RR ডিজাইনের breakeven ~১৪–১৫% winrate লাগে, কিন্তু OOS-এ TP দূরে হওয়ায় মাত্র ~৯–১২% hit হয় → **সামান্য ব্যবধানে bleeds**। IS-এ winrate breakeven-এর উপরে ছিল (তাই IS ভালো দেখাত)। ⇒ **মূল সমস্যা "TP বড্ড দূরে", SL-tight নয়।**

**সততার সীমা:** OnTester CSV-তে **exit time** থাকে (entry time নয়), তাই entry-ঘণ্টা histogram সরাসরি পাওয়া যায়নি; entries কোডে 9:30–16:00 **server** সময়ে gated (spec §8: server≠NY হতে পারে — আলাদা সম্ভাব্য বিষয়)। tester.log-এর TP/SL গণনা তারিখ-লগে cumulative হওয়ায় দূষিত — তাই CSV-ই authoritative।

## অংশ ২ — creator-specified বিকল্প TP টেস্ট (নিকটবর্তী = opposite H1 key level)

diagnosis অনুযায়ী spec §6-এর বিকল্প TP implement করলাম (`InpTPMode=2` = entry-এর নিকটতম বিপরীত H1 swing level; full-external-এর বদলে), SMT=on, বাকি সব pinned।

| উইন্ডো | ট্রেড | win rate | realized RR | PF | রায় |
|---|---|---|---|---|---|
| IS | 20 | **35%** (↑ ২২.৬ থেকে) | ~1.2 | 0.66 | লোকসান |
| OOS | 38 | **29%** (↑ ১১.৭ থেকে) | ~1.4 | 0.57 | লোকসান |
| cr_h1 | 22 | 22.7% | ~1.15 | 0.34 | লোকসান |
| cr_h2 | 24 | 33% | ~1.4 | 0.70 | লোকসান |

**যা ঘটল:** নিকটবর্তী TP win rate সত্যিই বাড়াল (diagnosis সঠিক) — কিন্তু reward আরও বেশি কমল (RR ~৬x→~১.৩x)। তাই breakeven winrate ~৪৫%-এ উঠে গেল, আর actual ~৩০% আরও নিচে → **সব উইন্ডোতেই লোকসান, এমনকি IS-ও (PF ০.৬৬)**।

## তিন শর্তের বিচার (নিকটবর্তী TP)
1. OOS PF>1 ও cost-সহনশীল → ❌ (0.57)
2. current-regime দুই অর্ধেই PF>1 → ❌ (cr_h1 0.34, cr_h2 0.70)
3. IS→OOS ধস নেই → অপ্রযোজ্য (IS নিজেই লোকসানি)

**তিনটির একটিও পাস করেনি।**

## চূড়ান্ত সৎ রায় (faithful QM/ICT সম্পূর্ণ)

চারটি faithful কনফিগ MT5-এ পরীক্ষিত: (১) full-external TP SMT-off, (২) SMT-on, (৩) QM+OB/FVG confluence, (৪) নিকটবর্তী H1-key TP।

- দূরের TP: IS ভালো, কিন্তু OOS win rate breakeven-এর নিচে → লোকসানি।
- নিকটবর্তী TP: win rate বাড়ে, কিন্তু reward এত কমে যে edge পুরো মুছে যায় — **IS-ও লোকসানি**।

**⇒ faithful QM/ICT-এর কোনো configuration-এই robust, current, খরচ-সহনশীল edge নেই।** শক্তিশালী IS ছিল regime-নির্দিষ্ট (কয়েকটা বড় দূর-TP winner), OOS-এ generalize করে না। কোনো profit-tuning করা হয়নি; কোনো লাইভ/আসল-টাকা পদক্ষেপ নেওয়া হয়নি।

এটি সম্পূর্ণ প্রজেক্টের সাথে সঙ্গতিপূর্ণ: repo-র কোনো strategy এখন robust current edge দেখায় না। আসল deliverable = এই সৎ, reproducible, MT5-only যাচাই-ল্যাব + tamper-evident ledger।

---
*সব ট্রেড MT5-এ (real ticks); Python শুধু হিসাব; সব input pinned; সব রান hash-chained ledger-এ (seq 96–101)।*
