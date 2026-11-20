"""Noise helpers for the robustness test (numpy/scipy only)."""
import os, numpy as np
from math import gcd
from scipy.signal import butter, filtfilt, resample_poly

FS = 100
_b, _a = butter(3, [0.5, 40.0], btype="bandpass", fs=FS)


def bandpass_z(X):
    """Same filtering + per-window z-score as common.preprocess (X: [N, T] at 100 Hz)."""
    Y = filtfilt(_b, _a, X, axis=1)
    return ((Y - Y.mean(1, keepdims=True)) / (Y.std(1, keepdims=True) + 1e-8)).astype(np.float32)


def load_nstdb(folder):
    """Real noise from MIT-BIH Noise Stress Test DB: records bw (baseline wander), em (electrode motion), ma (muscle). 360 Hz -> 100 Hz."""
    import wfdb
    bank = {}
    for name in ("bw", "em", "ma"):
        sig, meta = wfdb.rdsamp(os.path.join(folder, name))
        fs = int(meta["fs"]); g = gcd(fs, FS)
        bank[name] = resample_poly(sig[:, 0].astype(np.float64), FS // g, fs // g)
    return bank


def synthetic_bank(seed=0, n=180000):
    """Fallback when nstdb is not available (clearly NOT real noise)."""
    r = np.random.default_rng(seed); t = np.arange(n) / FS
    bw = sum(np.sin(2*np.pi*f*t + r.uniform(0, 6.28)) * a for f, a in ((0.15, 1.0), (0.3, 0.7), (0.45, 0.5)))
    em = np.convolve(r.standard_normal(n), np.ones(15) / 15, mode="same") * (1 + 3 * (r.random(n) > 0.995).cumsum() % 2)
    ma = r.standard_normal(n)
    return {"bw": bw, "em": em, "ma": ma}


def add_noise(X, bank, kind, snr_db, rng):
    """X: z-scored windows [N, T]. kind: bw/em/ma/mix. Noise is scaled per window to the target SNR (signal power = 1),
    added, then the deployment filter + z-score is applied again."""
    N, T = X.shape; out = np.empty_like(X)
    names = ["bw", "em", "ma"] if kind == "mix" else [kind]
    scale = np.sqrt(10 ** (-snr_db / 10))
    for i in range(N):
        seg = 0
        for nm in names:
            src = bank[nm]; s = rng.integers(0, len(src) - T)
            x = src[s:s+T] - src[s:s+T].mean(); seg = seg + x / (x.std() + 1e-8)
        seg = seg / (len(names) ** 0.5)
        out[i] = X[i] + scale * seg
    return bandpass_z(out)
