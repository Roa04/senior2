"""Shared constants + preprocessing. Training and the FastAPI server MUST both use preprocess()."""
import numpy as np
from scipy.signal import butter, filtfilt, iirnotch, resample_poly
from math import gcd

LEAD = "II"          # lead used for training (PTB-XL name)
FS = 100             # model sampling rate (Hz) -> PTB-XL records100
WIN = 10 * FS        # 10 s window = 1000 samples
CLASSES = ["Normal", "Abnormal", "Critical"]   # 0, 1, 2


def preprocess(x, fs_in, fs_out=FS, win=WIN):
    """x: 1-D raw ECG (any fs_in, e.g. 250 Hz from ESP32). Returns float32 array [win]."""
    x = np.asarray(x, dtype=np.float64)
    if fs_in != fs_out:
        g = gcd(int(fs_in), int(fs_out))
        x = resample_poly(x, int(fs_out) // g, int(fs_in) // g)
    # band-pass 0.5-40 Hz (removes baseline wander + EMG/mains), zero-phase
    b, a = butter(3, [0.5, 40.0], btype="bandpass", fs=fs_out)
    x = filtfilt(b, a, x)
    # pad / crop to fixed length
    if len(x) < win:
        x = np.pad(x, (0, win - len(x)), mode="edge")
    else:
        x = x[:win]
    # per-window z-score (device and PTB-XL amplitudes differ -> only shape matters)
    x = (x - x.mean()) / (x.std() + 1e-8)
    return x.astype(np.float32)
