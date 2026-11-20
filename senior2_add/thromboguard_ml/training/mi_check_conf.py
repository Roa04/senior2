"""MI vs Normal on TEST (fold 10): ALL records vs HIGH-CONFIDENCE subsets. No training. Threshold is fixed on the FULL validation set
(so we do not tune anything per subset). Subsets are defined here, BEFORE looking at results.
usage: python mi_check_conf.py "<PTB-XL folder>"      (needs data/X12.npy, data/y.npy, data/folds.npy, model12.pt)"""
import sys, numpy as np, pandas as pd, torch, torch.nn as nn, torch.nn.functional as F
from sklearn.metrics import roc_auc_score
from train import ECGNet, dev
from prepare_data import load_meta

SETS = {"II only": [1], "I+II": [0, 1]}
class Net12(ECGNet):
    def __init__(s):
        super().__init__(); s.stem = nn.Sequential(nn.Conv1d(12, 32, 15, 2, 7, bias=False), nn.BatchNorm1d(32), nn.ReLU())

def probs(model, X, idxs, b=256):
    model.eval(); mk = torch.zeros(1, 12, 1); mk[0, idxs] = 1; mk = mk.to(dev); out = []
    with torch.no_grad():
        for i in range(0, len(X), b):
            out.append(F.softmax(model(torch.from_numpy(X[i:i+b].astype(np.float32)).to(dev) * mk), 1).cpu().numpy())
    return np.concatenate(out)

def best_thr(s, t):
    return max(np.linspace(0.05, 0.95, 91), key=lambda th: ((s >= th)[t].mean() + (~(s >= th))[~t].mean()) / 2)

def boot_ci(t, s, n=300, seed=0):
    r = np.random.default_rng(seed); a = []
    for _ in range(n):
        i = r.integers(0, len(t), len(t))
        if 0 < t[i].sum() < len(i): a.append(roc_auc_score(t[i], s[i]))
    return np.percentile(a, [2.5, 97.5])

root = sys.argv[1]
df = load_meta(root); agg = pd.read_csv(f"{root}/scp_statements.csv", index_col=0); agg = agg[agg["diagnostic"] == 1]
def conf(row):
    codes = {k: v for k, v in row["scp_codes"].items() if k in agg.index}
    want = {0: "NORM", 2: "MI"}.get(row["label"])
    sel = [v for k, v in codes.items() if agg.loc[k, "diagnostic_class"] == want]
    return max(sel) if sel else 0
c = df.apply(conf, axis=1).values
valid = df["validated_by_human"].fillna(False).astype(bool).values
X, y, folds = np.load("data/X12.npy"), np.load("data/y.npy"), np.load("data/folds.npy")
assert len(df) == len(y) and np.array_equal(df["label"].values, y), "order differs from data/y.npy"
m = Net12().to(dev); m.load_state_dict(torch.load("model12.pt", map_location=dev))

sel = lambda f: (folds == f) & (y != 1)                          # Normal + MI only
kv, kt = np.where(sel(9))[0], np.where(sel(10))[0]
SUB = {"A: all test records": np.ones(len(kt), bool), "B: label confidence >= 80": c[kt] >= 80,
       "C: label confidence == 100": c[kt] >= 100, "D: human-validated": valid[kt]}
print("\nTEST subsets (Normal+MI only):")
for k, mk in SUB.items(): print(f"  {k:30s} n={mk.sum():5d}  (MI {int((y[kt][mk] == 2).sum())}, Normal {int((y[kt][mk] == 0).sum())})")
for n, idx in SETS.items():
    Pv, Pt = probs(m, X[kv], idx), probs(m, X[kt], idx)
    sv, st = Pv[:, 2] / (Pv[:, 0] + Pv[:, 2]), Pt[:, 2] / (Pt[:, 0] + Pt[:, 2])
    th = best_thr(sv, y[kv] == 2); print(f"\n=== {n}  (threshold {th:.2f}, fixed on full validation) ===")
    print(f"{'subset':30s} | AUC [95% CI]          | acc   sens/spec")
    for k, mk in SUB.items():
        t, s = y[kt][mk] == 2, st[mk]; p = s >= th; lo, hi = boot_ci(t, s)
        print(f"{k:30s} | {roc_auc_score(t, s):.4f} [{lo:.3f}-{hi:.3f}] | {(p == t).mean():.3f} {p[t].mean():.2f}/{(~p[~t]).mean():.2f}")
