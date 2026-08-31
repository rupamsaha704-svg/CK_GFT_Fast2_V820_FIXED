"""Combinatorial Purged Cross-Validation (CPCV) - vendored from loadchange/ai-hedge-fund
(López de Prado, Advances in Financial ML, ch.7). numpy-only, standalone."""
from __future__ import annotations
from itertools import combinations
from typing import Iterator
import numpy as np


class CombinatorialPurgedKFold:
    def __init__(self, n_splits: int = 8, n_test_splits: int = 2, embargo_pct: float = 0.01) -> None:
        if n_splits < 2:
            raise ValueError("n_splits must be >= 2")
        if n_test_splits < 1 or n_test_splits >= n_splits:
            raise ValueError("0 < n_test_splits < n_splits")
        if not 0 <= embargo_pct < 0.5:
            raise ValueError("embargo_pct must be in [0, 0.5)")
        self.n_splits = n_splits
        self.n_test_splits = n_test_splits
        self.embargo_pct = embargo_pct

    def get_n_splits(self) -> int:
        from math import comb
        return comb(self.n_splits, self.n_test_splits)

    def split(self, n_samples: int) -> Iterator[tuple[np.ndarray, np.ndarray]]:
        if n_samples < self.n_splits:
            raise ValueError(f"n_samples={n_samples} must be >= n_splits={self.n_splits}")
        bounds = np.linspace(0, n_samples, self.n_splits + 1, dtype=int)
        groups = [np.arange(bounds[i], bounds[i + 1]) for i in range(self.n_splits)]
        embargo_size = int(n_samples * self.embargo_pct)
        for test_combo in combinations(range(self.n_splits), self.n_test_splits):
            test_idx = np.concatenate([groups[i] for i in sorted(test_combo)])
            embargo_mask = np.zeros(n_samples, dtype=bool)
            for i in test_combo:
                start = max(0, bounds[i] - embargo_size)
                end = min(n_samples, bounds[i + 1] + embargo_size)
                embargo_mask[start:end] = True
            train_idx = np.where(~embargo_mask)[0]
            yield train_idx, test_idx


def generate_splits(n_samples, *, n_splits=8, n_test_splits=2, embargo_pct=0.01):
    return list(CombinatorialPurgedKFold(n_splits, n_test_splits, embargo_pct).split(n_samples))
