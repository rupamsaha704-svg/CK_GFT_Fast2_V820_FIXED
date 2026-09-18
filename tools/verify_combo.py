import pandas as pd, numpy as np, re, os

DEP = 5000.0
CSV = r"experiments\combo_1y\windows\last1y\trades.csv"
HTM = r"experiments\combo_1y\windows\last1y\report.htm"

# ---- CSV (native single-account combined deals) ----
df = pd.read_csv(CSV)
df.columns = [c.strip().lower() for c in df.columns]
df["time"] = pd.to_datetime(df["time"], format="%Y.%m.%d %H:%M")
df["profit"] = pd.to_numeric(df["profit"], errors="coerce").fillna(0.0)
df["magic"] = df["magic"].astype(str)
df = df.sort_values("time").reset_index(drop=True)

prof = df["profit"].values
eq = np.concatenate([[DEP], DEP + np.cumsum(prof)])
net = prof.sum()
gp = prof[prof > 0].sum(); gl = prof[prof < 0].sum()
pf = gp / abs(gl) if gl != 0 else float("inf")
n = len(df); nz = df[df["profit"] != 0]
win = (nz["profit"] > 0).mean() * 100 if len(nz) else 0
min_eq = eq.min(); static_dd = max(0.0, DEP - min_eq)
peak = np.maximum.accumulate(eq); trail = ((peak - eq) / peak * 100).max()

run = DEP; worst_day = 0.0
for _, g in df.groupby(df["time"].dt.date):
    s = run; pl = g["profit"].sum(); run += pl
    if pl < 0 and pl / s * 100 < worst_day:
        worst_day = pl / s * 100

FIX = "20260716"; DT = "20260930"
fn = df[df["magic"] == FIX]["profit"].sum(); fc = (df["magic"] == FIX).sum()
dn = df[df["magic"] == DT]["profit"].sum(); dc = (df["magic"] == DT).sum()

print("===== NATIVE COMBINED (from MT5 combo CSV, closed-trade) =====")
print(f"  trades           : {n}  (FIX09 {fc} / DTREND {dc})")
print(f"  net              : {net:,.2f}  ({net/DEP*100:+.2f}%)   end ${DEP+net:,.2f}")
print(f"  profit factor    : {pf:.2f}")
print(f"  win rate (nz)    : {win:.1f}%")
print(f"  STATIC DD (<5k)  : {static_dd:,.2f}  ({static_dd/DEP*100:.2f}%)   [limit 10%]")
print(f"  trailing DD      : {trail:.2f}%")
print(f"  worst day        : {worst_day:.2f}%   [limit 5%]")
print(f"  FIX09 / DTREND $ : {fn:,.2f} / {dn:,.2f}")

# ---- HTM (MT5's own computed figures) ----
def htm_text(p):
    for enc in ("utf-16", "utf-16-le", "utf-8"):
        try:
            raw = open(p, "r", encoding=enc, errors="strict").read(); break
        except Exception:
            raw = None
    if raw is None:
        raw = open(p, "rb").read().decode("utf-16", errors="ignore")
    raw = re.sub(r"<[^>]+>", "|", raw)
    raw = raw.replace("&nbsp;", " ")
    return raw

def grab(txt, label):
    # find label then the first number-looking token after it
    i = txt.find(label)
    if i < 0: return None
    seg = txt[i+len(label): i+len(label)+80]
    m = re.search(r"-?\d[\d \u00a0.,]*", seg)
    if not m: return None
    v = m.group(0).replace("\u00a0", "").replace(" ", "").replace(",", "")
    return v

if os.path.exists(HTM):
    t = htm_text(HTM)
    print("\n===== MT5 NATIVE HTM figures =====")
    for lab in ["Total Net Profit:", "Gross Profit:", "Gross Loss:", "Profit Factor:",
                "Expected Payoff:", "Recovery Factor:", "Sharpe Ratio:",
                "Balance Drawdown Absolute:", "Balance Drawdown Maximal:",
                "Equity Drawdown Absolute:", "Equity Drawdown Maximal:",
                "Total Trades:"]:
        v = grab(t, lab)
        if v is not None:
            print(f"  {lab:32s} {v}")
else:
    print("HTM not found")
