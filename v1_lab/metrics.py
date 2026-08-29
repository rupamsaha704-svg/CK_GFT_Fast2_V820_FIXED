#!/usr/bin/env python3
"""
Canonical metrics — the ONLY implementation of METRIC DICTIONARY v1.0.
Every pipeline stage must import from here (no ad-hoc recomputation => no metric drift).
"""
import datetime

DEPOSIT_DEFAULT = 5000.0
# session boundaries (server time), pre-declared & locked
SESSIONS = [("Asia", 0, 8), ("London", 8, 13), ("LDN_NY", 13, 17), ("NY_late", 17, 24)]

def load_trades(path):
    """CSV: header 'time,profit'; rows 'YYYY.MM.DD HH:MM,<net_profit>'. Returns [(datetime|None, float)]."""
    rows = []
    with open(path) as fh:               # explicit context manager: no unclosed-file ResourceWarning
        for l in fh:
            l = l.strip()
            if not l or l.lower().startswith('time,'): continue
            t, pf = l.rsplit(',', 1)
            try: d = datetime.datetime.strptime(t, "%Y.%m.%d %H:%M")
            except Exception: d = None
            rows.append((d, float(pf)))
    return rows

def gross(rows):
    gw = sum(p for _, p in rows if p > 0)
    gl = abs(sum(p for _, p in rows if p < 0))
    return gw, gl

def profit_factor(rows):
    gw, gl = gross(rows)
    return (gw / gl) if gl > 0 else float('inf')

def net_profit(rows):        return sum(p for _, p in rows)
def n_trades(rows):          return len(rows)
def wins(rows):              return [p for _, p in rows if p > 0]
def losses(rows):            return [p for _, p in rows if p < 0]
def win_rate(rows):          return (len(wins(rows)) / len(rows) * 100) if rows else 0.0
def expectancy(rows):        return (net_profit(rows) / len(rows)) if rows else 0.0
def avg_win(rows):           w = wins(rows);  return (sum(w)/len(w)) if w else 0.0
def avg_loss(rows):          l = losses(rows); return (sum(l)/len(l)) if l else 0.0

def equity_curve(rows, dep=DEPOSIT_DEFAULT):
    eq = dep; curve = [dep]
    for _, p in rows: eq += p; curve.append(eq)
    return curve

def max_dd_closed(rows, dep=DEPOSIT_DEFAULT):
    """closed-trade max drawdown as % of running peak."""
    eq = dep; peak = dep; mdd = 0.0
    for _, p in rows:
        eq += p
        if eq > peak: peak = eq
        dd = (peak - eq) / peak if peak > 0 else 0.0
        if dd > mdd: mdd = dd
    return mdd * 100.0

def session_of(hour):
    for name, a, b in SESSIONS:
        if a <= hour < b: return name
    return "NY_late"

def summary(rows, dep=DEPOSIT_DEFAULT):
    return {
        "trades": n_trades(rows),
        "net": net_profit(rows),
        "return_pct": 100.0 * net_profit(rows) / dep,
        "pf": profit_factor(rows),
        "win_rate": win_rate(rows),
        "expectancy": expectancy(rows),
        "avg_win": avg_win(rows),
        "avg_loss": avg_loss(rows),
        "max_dd_closed_pct": max_dd_closed(rows, dep),
    }

if __name__ == '__main__':
    import sys
    r = load_trades(sys.argv[1]); dep = float(sys.argv[2]) if len(sys.argv) > 2 else DEPOSIT_DEFAULT
    s = summary(r, dep)
    print("METRIC DICTIONARY v1.0 — canonical summary")
    for k, v in s.items():
        print(f"  {k:18} {v:.2f}" if isinstance(v, float) else f"  {k:18} {v}")
