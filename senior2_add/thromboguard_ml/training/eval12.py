"""Evaluate the saved model12.pt on TEST (fold 10) with different available leads. No training.
usage: python eval12.py"""
import numpy as np, torch, torch.nn as nn, torch.nn.functional as F
from sklearn.metrics import roc_auc_score
from train import ECGNet, dev
from nets import thr_table

SETS = {"II only": [1], "I+II": [0, 1], "6 limb leads": [0, 1, 2, 3, 4, 5], "all 12 leads": list(range(12))}

class Net12(ECGNet):
    def __init__(s):
        super().__init__()
        s.stem = nn.Sequential(nn.Conv1d(12, 32, 15, 2, 7, bias=False), nn.BatchNorm1d(32), nn.ReLU())

def predict(model, X, name, b=256):
    model.eval(); mk = torch.zeros(1, 12, 1); mk[0, SETS[name]] = 1; mk = mk.to(dev); out = []
    with torch.no_grad():
        for i in range(0, len(X), b):
            xb = torch.from_numpy(X[i:i+b].astype(np.float32)).to(dev) * mk
            out.append(F.softmax(model(xb), 1).cpu().numpy())
    return np.concatenate(out)

X, y, folds = np.load("data/X12.npy"), np.load("data/y.npy"), np.load("data/folds.npy")
va, te = folds == 9, folds == 10
m = Net12().to(dev); m.load_state_dict(torch.load("model12.pt", map_location=dev)); yt = y[te]
if __name__ == '__main__':
    print("\n=== TEST (fold 10) ===")
    print(f"{'leads given':14s} | macro AUC | accuracy | Critical AUC | Critical recall")
    for n in SETS:
        P = predict(m, X[te], n); pr = P.argmax(1)
        print(f"{n:14s} | {roc_auc_score(yt, P, multi_class='ovr', average='macro'):9.4f} | {(pr == yt).mean():8.3f} | {roc_auc_score(yt == 2, P[:, 2]):12.4f} | {(pr[yt == 2] == 2).mean():.3f}")
    for n in ("II only", "all 12 leads"):
        thr_table(predict(m, X[va], n), y[va], f"{n} - validation")
        thr_table(predict(m, X[te], n), yt, f"{n} - test")
