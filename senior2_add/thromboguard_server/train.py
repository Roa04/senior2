"""Train a 1D ResNet on lead-II PTB-XL (3 classes). usage: python train.py [data_dir]
Split follows PTB-XL recommendation: folds 1-8 train, 9 val, 10 test."""
import sys, numpy as np, torch, torch.nn as nn, torch.nn.functional as F
from sklearn.metrics import roc_auc_score, f1_score, confusion_matrix, classification_report
from common import CLASSES, WIN

dev = "cuda" if torch.cuda.is_available() else "cpu"
torch.manual_seed(0); np.random.seed(0)


class Block(nn.Module):
    def __init__(s, cin, cout, stride):
        super().__init__()
        s.c1 = nn.Conv1d(cin, cout, 7, stride, 3, bias=False); s.b1 = nn.BatchNorm1d(cout)
        s.c2 = nn.Conv1d(cout, cout, 7, 1, 3, bias=False);     s.b2 = nn.BatchNorm1d(cout)
        s.sk = None if (cin == cout and stride == 1) else nn.Sequential(
            nn.Conv1d(cin, cout, 1, stride, bias=False), nn.BatchNorm1d(cout))
        s.drop = nn.Dropout(0.2)
    def forward(s, x):
        o = F.relu(s.b1(s.c1(x))); o = s.drop(o); o = s.b2(s.c2(o))
        return F.relu(o + (x if s.sk is None else s.sk(x)))


class ECGNet(nn.Module):
    def __init__(s, n_cls=3):
        super().__init__()
        s.stem = nn.Sequential(nn.Conv1d(1, 32, 15, 2, 7, bias=False), nn.BatchNorm1d(32), nn.ReLU())
        s.body = nn.Sequential(Block(32, 32, 1), Block(32, 64, 2), Block(64, 64, 1),
                               Block(64, 128, 2), Block(128, 128, 1), Block(128, 256, 2))
        s.head = nn.Linear(256 * 2, n_cls)
    def forward(s, x):                      # x: [B,1,T]
        h = s.body(s.stem(x))
        return s.head(torch.cat([h.mean(-1), h.amax(-1)], 1))


def augment(x):
    """x: [B,1,T] tensor. Simulates wrist-wearable noise so the model survives AD8232 signals."""
    B, _, T = x.shape
    t = torch.arange(T, device=x.device).float() / 100.0
    # baseline wander (0.1-0.5 Hz)
    f = torch.empty(B, 1, 1, device=x.device).uniform_(0.1, 0.5)
    ph = torch.empty(B, 1, 1, device=x.device).uniform_(0, 6.28)
    amp = torch.empty(B, 1, 1, device=x.device).uniform_(0, 0.5)
    x = x + amp * torch.sin(2 * 3.1416 * f * t + ph)
    # muscle / electrode noise
    x = x + torch.randn_like(x) * torch.empty(B, 1, 1, device=x.device).uniform_(0, 0.15)
    # amplitude scaling + random circular shift
    x = x * torch.empty(B, 1, 1, device=x.device).uniform_(0.7, 1.3)
    shift = np.random.randint(-100, 100)
    return torch.roll(x, shift, dims=-1)


def predict(model, X, bs=256):
    model.eval(); out = []
    with torch.no_grad():
        for i in range(0, len(X), bs):
            xb = torch.from_numpy(X[i:i+bs]).unsqueeze(1).to(dev)
            out.append(F.softmax(model(xb), 1).cpu().numpy())
    return np.concatenate(out)


EPOCH_SAMPLES = 5000   # samples per "epoch" (set to None for full 17k)


def main(d="data", epochs=6, bs=64):
    X, y, folds = np.load(f"{d}/X.npy"), np.load(f"{d}/y.npy"), np.load(f"{d}/folds.npy")
    tr, va, te = folds <= 8, folds == 9, folds == 10
    print("train/val/test:", tr.sum(), va.sum(), te.sum(), "| class counts:", np.bincount(y))
    w = 1.0 / np.bincount(y[tr]); w = torch.tensor(w / w.sum() * 3, dtype=torch.float32, device=dev)
    model = ECGNet().to(dev)
    import os
    if os.path.exists("model.pt"):
        model.load_state_dict(torch.load("model.pt", map_location=dev)); print("resumed from model.pt")
    opt = torch.optim.AdamW(model.parameters(), 1e-3, weight_decay=1e-2)
    sched = torch.optim.lr_scheduler.OneCycleLR(opt, 3e-3, total_steps=int(epochs * ((EPOCH_SAMPLES or int(tr.sum())) // bs + 1)))
    Xtr, ytr = X[tr], y[tr]; best, bad = 0, 0
    for ep in range(epochs):
        model.train(); perm = np.random.permutation(len(Xtr))[:EPOCH_SAMPLES]; tot = 0
        for i in range(0, len(perm), bs):
            idx = perm[i:i+bs]
            xb = torch.from_numpy(Xtr[idx]).unsqueeze(1).to(dev)
            yb = torch.from_numpy(ytr[idx]).long().to(dev)
            loss = F.cross_entropy(model(augment(xb)), yb, weight=w)
            opt.zero_grad(); loss.backward(); opt.step(); sched.step(); tot += loss.item() * len(idx)
            if (i // bs) % 20 == 0: print(f"  batch {i//bs}/{len(perm)//bs} loss {loss.item():.3f}", flush=True)
        pv = predict(model, X[va])
        auc = roc_auc_score(y[va], pv, multi_class="ovr", average="macro")
        print(f"ep {ep+1:02d} loss {tot/len(perm):.4f} val macro-AUC {auc:.4f}", flush=True)
        if auc > best: best, bad = auc, 0; torch.save(model.state_dict(), "model.pt")
        else:
            bad += 1
            if bad >= 8: print("early stop"); break
    model.load_state_dict(torch.load("model.pt", map_location=dev))
    pt = predict(model, X[te]); yt = y[te]; pred = pt.argmax(1)
    print("\n=== TEST (fold 10) ===")
    print("macro AUC:", roc_auc_score(yt, pt, multi_class="ovr", average="macro"))
    for k, n in enumerate(CLASSES):
        print(f"AUC {n}: {roc_auc_score(yt == k, pt[:, k]):.4f}")
    print("macro F1:", f1_score(yt, pred, average="macro"))
    print(classification_report(yt, pred, target_names=CLASSES, digits=3))
    print("confusion matrix:\n", confusion_matrix(yt, pred))
    torch.onnx.export(model.cpu().eval(), torch.zeros(1, 1, WIN), "model.onnx",
                      input_names=["ecg"], output_names=["logits"], dynamic_axes={"ecg": {0: "b"}})


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "data")
