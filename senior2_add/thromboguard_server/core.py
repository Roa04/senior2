"""ThromboGuard server core (no web framework, no torch import -> easy to test).
analyze(payload, predict_fn) -> dict matching the Flutter app's CloudApi contract:
   {"risk_class": 0|1|2, "reasons": [...], "ecg_probabilities": {"Normal","Abnormal","Critical"}, + extras}
predict_fn(x_1000: np.ndarray float32) -> (p_normal, p_abnormal, p_critical)   (Lead II, preprocessed, 100 Hz, 10 s)
"""
import os
import numpy as np
from scipy.signal import find_peaks
from common import preprocess
import alert

HIGH_TO_CRITICAL = os.environ.get("HIGH_TO_CRITICAL", "0") == "1"   # MI-like ECG alone -> red screen? default: NO (needs vitals)
MIN_SECONDS = 5
LEVEL_TO_RISK = {"NORMAL": 0, "ATTENTION": 1, "HIGH": 2 if HIGH_TO_CRITICAL else 1, "CRITICAL": 2}
if os.environ.get("THR_MI"): alert.THR_MI = float(os.environ["THR_MI"])


class BadSignal(Exception):
    """ECG window unusable (flat, clipped, too short, no heartbeats...). Server answers HTTP 422, the app shows an error
    instead of a false 'Normal'."""


def signal_quality(raw, fs):
    x = np.asarray(raw, dtype=np.float64)
    if x.size < MIN_SECONDS * fs: return f"ECG window too short ({x.size / fs:.1f}s < {MIN_SECONDS}s)"
    if not np.isfinite(x).all(): return "ECG contains NaN/inf"
    if x.std() < 1e-6: return "ECG is flat (electrodes off?)"
    if (np.mean(x == x.max()) > 0.05) or (np.mean(x == x.min()) > 0.05): return "ECG is clipped/saturated"
    z = preprocess(x, fs)                                           # filtered + z-scored (first 10 s at 100 Hz)
    seg = z[: int(min(x.size / fs, 10) * 100)]
    sig = 1.4826 * np.median(np.abs(seg - np.median(seg))) + 1e-9    # robust noise level (heartbeat spikes barely move it)
    peaks, _ = find_peaks(np.abs(seg), distance=25, prominence=5 * sig)   # R peaks must stand out >= 5x the noise level
    bpm = len(peaks) / (len(seg) / 100) * 60
    if len(peaks) < 3 or not (30 <= bpm <= 220): return "no clear heartbeats detected (poor contact or too much noise)"
    return None


def analyze(p, predict_fn):
    ecg = p.get("ecg") or []
    fs = int(p.get("sampling_rate") or 250)
    hr = p.get("heart_rate"); spo2 = p.get("spo2")
    hr = None if not hr else float(hr)                              # 0 = no reading
    spo2 = None if not spo2 else float(spo2)
    fall = bool(p.get("fall_detected", False))

    problem = signal_quality(ecg, fs)
    if problem is None:
        pn, pa, pc = predict_fn(preprocess(ecg, fs))
        score = alert.mi_score(pn, pc)
    else:
        pn, pa, pc, score = 1.0, 0.0, 0.0, 0.0

    d = alert.decide_alert(score, spo2=spo2, hr=hr, motion=0.0)
    level, reasons = d["level"], list(d["reasons"])
    if fall and score >= alert.THR_MI and level in ("HIGH", "CRITICAL"):
        level = "CRITICAL"; reasons.append("fall detected together with an MI-like ECG")
    elif fall:
        reasons.append("fall detected")

    if problem is not None:
        reasons.append("ECG not usable: " + problem)
        if level == "NORMAL": raise BadSignal(problem)              # never answer 'Normal' on a bad signal

    return {"risk_class": LEVEL_TO_RISK[level], "level": level, "message": d["message"], "reasons": reasons,
            "ecg_probabilities": {"Normal": float(pn), "Abnormal": float(pa), "Critical": float(pc)},
            "mi_score": score, "signal_ok": problem is None}
