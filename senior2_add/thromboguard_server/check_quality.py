"""Sanity check of the signal-quality gate on real PTB-XL Lead II (100 Hz). Should reject almost nothing.
usage: python check_quality.py          (needs data/X12.npy)"""
import numpy as np, core
X = np.load("data/X12.npy", mmap_mode="r"); n = len(X); idx = np.random.default_rng(0).choice(n, 1500, replace=False)
bad = {}
for i in idx:
    r = core.signal_quality(np.asarray(X[i, 1], dtype=np.float64), 100)
    if r: bad[r] = bad.get(r, 0) + 1
tot = sum(bad.values()); print(f"rejected {tot}/{len(idx)} ({100*tot/len(idx):.1f}%)"); [print("  ", v, k) for k, v in bad.items()]
print("OK if well under ~2%; if higher, the peak rule is too strict -> tell me the numbers.")
