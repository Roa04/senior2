"""python test_core.py -- decision logic with a fake model (no torch / fastapi needed). Model question: NORMAL or MI."""
import numpy as np, core

def fake_ecg(sec=10, fs=250, hr=72, noise=0.02, seed=0):
    rng = np.random.default_rng(seed); n = sec * fs; x = rng.normal(0, noise, n)
    for c in np.arange(0.5 * fs, n, 60 / hr * fs).astype(int):
        if c + 3 < n: x[c - 2:c + 3] += [0.2, 0.9, 3.0, -0.8, 0.1]
    return (x * 1000 + 2048).tolist()

NORMAL = lambda x: (0.95, 0.04, 0.01); MI = lambda x: (0.2, 0.1, 0.7)
base = dict(ecg=fake_ecg(), sampling_rate=250, heart_rate=75, spo2=97, fall_detected=False)
MIRED = 2 if core.HIGH_TO_CRITICAL else 1

def run(name, expect, fn, **kw):
    try: r = core.analyze({**base, **kw}, fn); got, lv = r["risk_class"], r["level"]
    except core.BadSignal as e: got, lv = "422", str(e)
    print(("OK  " if got == expect else "FAIL"), f"{name:44s} -> risk {got} ({lv})"); return got == expect

ok = [run("normal ECG + normal vitals", 0, NORMAL),
      run("MI-like ECG, vitals fine (HIGH -> yellow)", MIRED, MI),
      run("MI-like ECG + SpO2 86 -> CRITICAL", 2, MI, spo2=86),
      run("MI-like ECG + HR 140 -> CRITICAL", 2, MI, heart_rate=140),
      run("MI-like ECG + fall -> CRITICAL", 2, MI, fall_detected=True),
      run("normal ECG but SpO2 85 -> yellow", 1, NORMAL, spo2=85),
      run("no SpO2 / HR readings (0)", 0, NORMAL, spo2=0, heart_rate=0),
      run("flat signal -> 422", "422", NORMAL, ecg=[2048.0] * 2500),
      run("too short (2 s) -> 422", "422", NORMAL, ecg=fake_ecg(2)),
      run("noise only -> 422", "422", NORMAL, ecg=(np.random.default_rng(1).normal(2048, 50, 2500)).tolist()),
      run("flat ECG but SpO2 85 -> still alerts", 1, NORMAL, ecg=[2048.0] * 2500, spo2=85)]
print("\nALL PASSED" if all(ok) else "\nSOME FAILED"); raise SystemExit(0 if all(ok) else 1)
