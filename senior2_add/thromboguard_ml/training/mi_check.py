"""ONE self-contained script: MI (Critical) vs NORMAL using model12.pt. No training. Run:  python mi_check.py"""
import numpy as np, torch, torch.nn as nn, torch.nn.functional as F
from sklearn.metrics import roc_auc_score
from train import ECGNet, dev

SETS = {"II only": [1], "I+II": [0, 1], "6 limb leads": [0, 1, 2, 3, 4, 5], "all 12 leads": list(range(12))}

class Net12(ECGNet):
    def __init__(s):
        super().__init__()
        s.stem = nn.Sequential(nn.Conv1d(12, 32, 15, 2, 7, bias=False), nn.BatchNorm1d(32), nn.ReLU())

def probs(model, X, idxs, b=256):
    model.eval(); mk = torch.zeros(1, 12, 1); mk[0, idxs] = 1; mk = mk.to(dev); out = []
    with torch.no_grad():
        for i in range(0, len(X), b):
            xb = torch.from_numpy(X[i:i+b].astype(np.float32)).to(dev) * mk
            out.append(F.softmax(model(xb), 1).cpu().numpy())
    return np.concatenate(out)

def thr_for(s, t, mode):
    best = (0.5, -1)
    for th in np.linspace(0.05, 0.95, 91):
        pred = s >= th; sens = pred[t].mean(); spec = (~pred[~t]).mean()
        v = (sens + spec) / 2 if mode == "bal" else (spec if sens >= 0.90 else -1)
        if v > best[1]: best = (th, v)
    return best[0]

X, y, folds = np.load("data/X12.npy"), np.load("data/y.npy"), np.load("data/folds.npy")
m = Net12().to(dev); m.load_state_dict(torch.load("model12.pt", map_location=dev))
def keep(f):
    k = np.where(folds == f)[0]; return k[y[k] != 1]          # Normal(0) + Critical(2) only
kv, kt = keep(9), keep(10); yv, yt = y[kv] == 2, y[kt] == 2
print(f"\nTEST: {yt.sum()} MI vs {(~yt).sum()} Normal   (threshold chosen on validation)\n")
print(f"{'leads given':14s} | AUC    | balanced: acc  sens/spec | sens>=90%: acc  sens/spec")
for n, idx in SETS.items():
    Pv, Pt = probs(m, X[kv], idx), probs(m, X[kt], idx)
    sv, st = Pv[:, 2] / (Pv[:, 0] + Pv[:, 2]), Pt[:, 2] / (Pt[:, 0] + Pt[:, 2])
    line = f"{n:14s} | {roc_auc_score(yt, st):.4f}"
    for mode in ("bal", "s90"):
        p = st >= thr_for(sv, yv, mode)
        line += f" | {(p == yt).mean():.3f}  {p[yt].mean():.2f}/{(~p[~yt]).mean():.2f}"
    print(line)
