"""PBO + Deflated Sharpe - vendored from loadchange/ai-hedge-fund
(Bailey & López de Prado 2014). numpy+math only, standalone."""
from __future__ import annotations
import math
import numpy as np


def compute_pbo(is_sharpes: np.ndarray, oos_sharpes: np.ndarray) -> dict:
    is_sharpes = np.asarray(is_sharpes, dtype=float)
    oos_sharpes = np.asarray(oos_sharpes, dtype=float)
    if is_sharpes.shape != oos_sharpes.shape:
        raise ValueError(f"shape mismatch: IS {is_sharpes.shape}, OOS {oos_sharpes.shape}")
    n_trials, n_splits = is_sharpes.shape
    if n_trials < 2 or n_splits < 1:
        return {"pbo": float("nan"), "logits": [], "median_logit": float("nan"), "stochastic_dominance": False}
    logits = []
    for s in range(n_splits):
        best_is = int(np.argmax(is_sharpes[:, s]))
        oos_col = oos_sharpes[:, s]
        rank = float(np.mean(oos_col <= oos_col[best_is]))
        rank = min(max(rank, 1.0 / (n_trials + 1)), n_trials / (n_trials + 1))
        logits.append(math.log(rank / (1 - rank)))
    median_logit = float(np.median(logits))
    pbo = float(np.mean([l < 0 for l in logits]))
    return {"pbo": pbo, "logits": logits, "median_logit": median_logit,
            "stochastic_dominance": bool(median_logit > 0)}


def deflated_sharpe_ratio(sharpe, *, n_trials, n_obs, skewness=0.0, excess_kurtosis=0.0):
    if n_obs <= 1 or n_trials <= 1:
        return float("nan")
    emc = 0.5772156649
    z_n = (1 - emc) * _norm_ppf(1 - 1 / n_trials) + emc * _norm_ppf(1 - 1 / (n_trials * math.e))
    var = (1 - skewness * sharpe + (excess_kurtosis + 2) / 4 * sharpe ** 2) / (n_obs - 1)
    if var <= 0:
        return float("nan")
    z = (sharpe - z_n) / math.sqrt(var)
    return float(_norm_cdf(z))


def _norm_cdf(x):
    return 0.5 * (1 + math.erf(x / math.sqrt(2)))


def _norm_ppf(p):
    if not 0 < p < 1:
        return float("nan")
    a = (-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
         1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00)
    b = (-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
         6.680131188771972e+01, -1.328068155288572e+01)
    c = (-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
         -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00)
    d = (7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00, 3.754408661907416e+00)
    plow, phigh = 0.02425, 1 - 0.02425
    if p < plow:
        q = math.sqrt(-2 * math.log(p))
        return (((((c[0]*q+c[1])*q+c[2])*q+c[3])*q+c[4])*q+c[5]) / ((((d[0]*q+d[1])*q+d[2])*q+d[3])*q+1)
    if p <= phigh:
        q = p - 0.5; r = q*q
        return (((((a[0]*r+a[1])*r+a[2])*r+a[3])*r+a[4])*r+a[5])*q / (((((b[0]*r+b[1])*r+b[2])*r+b[3])*r+b[4])*r+1)
    q = math.sqrt(-2 * math.log(1 - p))
    return -(((((c[0]*q+c[1])*q+c[2])*q+c[3])*q+c[4])*q+c[5]) / ((((d[0]*q+d[1])*q+d[2])*q+d[3])*q+1)
