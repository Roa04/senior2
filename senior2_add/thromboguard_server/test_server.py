"""Send real PTB-XL Lead II records (one Normal, one MI) to the running server and print the answer.
usage: python test_server.py [http://localhost:8000]      (needs data/X12.npy, data/y.npy, data/folds.npy; server already running)"""
import sys, json, urllib.request, numpy as np
url = (sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000").rstrip("/")
X, y, f = np.load("data/X12.npy", mmap_mode="r"), np.load("data/y.npy"), np.load("data/folds.npy")

def post(path, body):
    req = urllib.request.Request(url + path, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=30) as r: return r.status, json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e: return e.code, e.read().decode("utf-8")

print("health:", urllib.request.urlopen(url + "/health", timeout=10).read().decode())
for name, cls in (("Normal", 0), ("MI", 2)):
    i = int(np.where((f == 10) & (y == cls))[0][0])
    ecg = np.asarray(X[i, 1], dtype=float).tolist()                       # Lead II, 100 Hz, 10 s
    code, r = post("/analyze", {"ecg": ecg, "sampling_rate": 100, "heart_rate": 75, "spo2": 97, "fall_detected": False})
    print(f"\n[{name} record, true label {cls}] HTTP {code}"); print(json.dumps(r, ensure_ascii=False, indent=1) if isinstance(r, dict) else r)
code, r = post("/analyze", {"ecg": [2048.0] * 1000, "sampling_rate": 100}); print("\n[flat signal] HTTP", code, r, "(expected 422)")
code, r = post("/advice", {"level": "abnormal", "heart_rate": 130, "spo2": 91}); print("\n[advice] HTTP", code, "source:", r.get("source") if isinstance(r, dict) else r)
if isinstance(r, dict): print(r["advice"])
