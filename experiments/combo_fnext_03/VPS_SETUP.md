# VPS SETUP — CK_GOLD_COMBO on FundedNext Stellar 2-Step $6,000

Why a VPS: MT5 must stay live 24/5 for the EA to catch fills and manage exits. Running
on your home PC (Ryzen 5 5600GT / 16 GB / offlined-E:) works technically but is fragile —
reboots, sleep, ISP drops, or a power blip all kill the EA. VPS runs are also the only
practical way to satisfy FundedNext's single-IP rule if you already trade manually from
your own IP.

## 1. Which VPS

Two viable paths:

- **FundedNext's own VPS add-on** — $10/month with an EA usage fee (small), the
  VPS+EA add-on cost is **refunded on the first payout** (per FundedNext client area).
  Simplest option, lowest friction, single-IP guaranteed, close to their MT5 server.
- **Independent forex VPS** — providers like ForexVPS, BeeksFX, NYCServers, Contabo,
  QuickTradingVPS. Pick one physically close to the FundedNext MT5 server (usually
  London or New York — check under Tools → Options → Server ping in MT5). Target
  latency **< 50 ms**. Cheapest usable spec: 2 vCPU / 4 GB RAM / 40 GB SSD, Windows
  Server 2019 or 2022.

Do NOT run two MT5 terminals on the same VPS if one is the live account and the other
is anything else — an incidental crossed hedge could trip FundedNext's
"mirrored / opposite positions across accounts" rule (Article 8020351).

## 2. Provisioning steps (independent VPS)

1. Sign up, pick a Windows Server plan (2 vCPU / 4 GB / 40 GB minimum).
2. When it's live you get: **IP address**, **Administrator username**, **password**.
3. On your dev PC open Remote Desktop Connection (Win+R → `mstsc`). Enter the VPS IP,
   accept the certificate warning, log in with Administrator + password.
4. Inside the VPS: download the MetaTrader 5 installer from FundedNext's client area
   (NOT metaquotes.net — use the FundedNext-branded installer so the correct server
   list is baked in).
5. Install MT5 → default path. Log into your FundedNext MT5 account (server + login +
   investor password NOT the master password unless you need to trade manually as well).
6. Copy this repo's `CK_GOLD_COMBO.mq5` and `CK_GOLD_COMBO_FundedNext.set` to the VPS
   — either via RDP clipboard drag-and-drop, or by pushing to GitHub and cloning on
   the VPS. Prefer clone-from-Git so the deploy is reproducible.
7. Run `experiments\combo_fnext_03\install_combo_fnext.ps1` from the repo root on the
   VPS. This does the same steps as on your local machine (copy → compile → verify).
8. Complete steps 1–7 of `FORWARD_DEMO.md` section A (attach, load preset, enable).

## 3. VPS-side hygiene

- **Auto-login on boot:** set Windows to auto-log-in as Administrator (`netplwiz`,
  uncheck "Users must enter a username and password"), so if the VPS reboots the MT5
  terminal auto-starts.
- **Auto-start MT5:** copy the MT5 shortcut into
  `C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup`.
- **Windows Update:** set to "Notify but don't auto-restart" — a forced 3 AM reboot in
  the middle of a live position is a bad day. Patch weekends only.
- **Antivirus:** disable Real-Time Scanning on the MT5 folders (`C:\Program Files\MetaTrader 5`
  and `C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\`) — false-positive
  quarantines have killed EAs mid-trade.
- **Sleep / hibernate:** OFF (Control Panel → Power Options → Never).
- **Timezone:** either match FundedNext server time (GMT+2 / GMT+3 DST) or leave UTC —
  do NOT match your local time; use the MT5 clock as the authority.
- **Monitoring:** open MT5 Tools → Options → Notifications. Add MetaQuotes Push ID
  from the MT5 mobile app so you get a phone push if the EA logs an error or if a
  trade opens/closes.
- **RDP session:** disconnect (X in top-right) instead of logging off, so MT5 keeps
  running. Logging off can kill the process.

## 4. Where the EA writes files (for the daily check)

MT5 Common\Files on the VPS:

    C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\
        ck_gold_combo_deals.csv     — every closed deal (used by tools\loss_visualizer)
        ck_gold_combo_trades.csv    — trade-level summary

Pull these to your dev PC via RDP clipboard, RoboCopy over the RDP-mapped drive, or push
to a private Git branch weekly. Never commit them to the public repo (they're your
private account history).

## 5. Cost / benefit reality check (steering §7)

The EA can only live on accounts **< $50,000**; accounts $50k and above are manual-only.
Combined with FundedNext's ban on "identical trades across accounts", the practical
ladder for THIS EA is:

- Grow ONE $6k live account under FundedNext's scale-up plan up to the sub-$50k cap.
- OR run a few DIFFERENTIATED sub-$50k accounts, each with a different set /
  strategy — but the multi-account portfolio question depends on the pending
  Trading Ethics reply (Article 8020351 mirror-position rule). Do not clone this
  exact `.set` to a second live account until that reply lands.

VPS math on $6k, take-80 minus $5/mo EA fee, funded-stage projected income ~$139/mo
= about the same as the $10 VPS refunded-on-first-payout add-on. Break-even is fast.
