"""Shared pieces for the improved pipeline: multi-task network, prediction, reports."""
import numpy as np, torch, torch.nn as nn, torch.nn.functional as F
from sklearn.metrics import roc_auc_score, f1_score, confusion_matrix, classification_report
from common import CLASSES
from train import ECGNet, dev


class ProNet(nn.Module):
    """Same signal backbone as ECGNet + two heads: 3 classes (main) and 5 superclasses (auxiliary)."""
    def __init__(s):
        super().__init__()
        b = ECGNet(); s.stem, s.body = b.stem, b.body
        s.head3 = nn.Linear(512, 3); s.head5 = nn.Linear(512, 5)
    def forward(s, x):
        h = s.body(s.stem(x)); f = torch.cat([h.mean(-1), h.amax(-1)], 1)
        return s.head3(f), s.head5(f)


def predict_probs(model, X, b=256):
    model.eval(); out = []
    with torch.no_grad():
        for i in range(0, len(X), b):
            xb = torch.from_numpy(X[i:i+b]).unsqueeze(1).to(dev)
            out.append(F.softmax(model(xb)[0], 1).cpu().numpy())
    return np.concatenate(out)


def thr_table(P, y, name):
    print(f"\n--- Critical threshold table ({name}) ---")
    print("rule      | Critical recall | Critical precision | MI flagged as any alert | Normal kept as Normal")
    rules = [("argmax", P.argmax(1))] + [(f"p>={t:.2f}", np.where(P[:, 2] >= t, 2, P[:, :2].argmax(1)))
                                         for t in (0.5, 0.4, 0.33, 0.3, 0.25, 0.2)]
    for nm, pred in rules:
        c = y == 2
        prec = (y[pred == 2] == 2).mean() if (pred == 2).any() else 0.0
        print(f"{nm:9s} | {(pred[c] == 2).mean():.3f}           | {prec:.3f}              | {(pred[c] >= 1).mean():.3f}                   | {(pred[y == 0] == 0).mean():.3f}")


def report(P, y, title):
    pred = P.argmax(1)
    print(f"\n=== {title} ===")
    print("macro AUC:", round(roc_auc_score(y, P, multi_class="ovr", average="macro"), 4))
    for k, n in enumerate(CLASSES): print(f"AUC {n}: {roc_auc_score(y == k, P[:, k]):.4f}")
    print("macro F1:", round(f1_score(y, pred, average="macro"), 4))
    print(classification_report(y, pred, target_names=CLASSES, digits=3))
    print("confusion matrix:\n", confusion_matrix(y, pred))
