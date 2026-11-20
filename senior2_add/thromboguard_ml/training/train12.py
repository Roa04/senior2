"""Train ONE model on 12 leads with random LEAD DROPOUT so it also works when only Lead II (or I+II, or 6 limb leads) is available.
Missing leads are fed as zeros. At the end the model is tested with: Lead II only / I+II / 6 limb leads / all 12 leads.
usage: python train12.py [epochs=12] [samples_per_epoch=8000]       -> saves model12.pt (never touches model.pt)"""
import sys, copy, time, numpy as np, torch, torch.nn as nn, torch.nn.functional as F
from sklearn.metrics import roc_auc_score
from common import CLASSES
from train import ECGNet, augment, dev
from nets import thr_table

epochs = int(sys.argv[1]) if len(sys.argv) > 1 else 12
n_ep = int(sys.argv[2]) if len(sys.argv) > 2 else 8000
bs = 64; torch.manual_seed(0); np.random.seed(0)
SETS = {"II only": [1], "I+II": [0, 1], "6 limb leads": [0, 1, 2, 3, 4, 5], "all 12 leads": list(range(12))}
NAMES = list(SETS)


class Net12(ECGNet):
    def __init__(s):
        super().__init__()
        s.stem = nn.Sequential(nn.Conv1d(12, 32, 15, 2, 7, bias=False), nn.BatchNorm1d(32), nn.ReLU())


def set_mask(idxs):
    m = torch.zeros(1, 12, 1); m[0, idxs] = 1; return m.to(dev)


def random_mask(B, p=(0.4, 0.2, 0.2, 0.2)):
    ch = np.random.choice(4, size=B, p=p); m = torch.zeros(B, 12, 1)
    for b, c in enumerate(ch): m[b, SETS[NAMES[c]]] = 1
    return m.to(dev)


def predict(model, X, name, b=256):
    model.eval(); mk = set_mask(SETS[name]); out = []
    with torch.no_grad():
        for i in range(0, len(X), b):
            xb = torch.from_numpy(X[i:i+b].astype(np.float32)).to(dev) * mk
            out.append(F.softmax(model(xb), 1).cpu().numpy())
    return np.concatenate(out)


X, y, folds = np.load("data/X12.npy"), np.load("data/y.npy"), np.load("data/folds.npy")
tr, va, te = folds <= 8, folds == 9, folds == 10
Xtr, ytr = X[tr], y[tr]
w = 1.0 / np.bincount(ytr); w = torch.tensor(w / w.sum() * 3, dtype=torch.float32, device=dev)
model = Net12().to(dev); ema = copy.deepcopy(model)
opt = torch.optim.AdamW(model.parameters(), 1e-3, weight_decay=1e-2)
sched = torch.optim.lr_scheduler.OneCycleLR(opt, 3e-3, total_steps=epochs * (n_ep // bs + 1), pct_start=0.2)
best, bad, t0 = 0.0, 0, time.time()
for ep in range(epochs):
    model.train(); perm = np.random.permutation(len(Xtr))[:n_ep]; tot = 0
    for i in range(0, len(perm), bs):
        idx = perm[i:i+bs]
        xb = torch.from_numpy(Xtr[idx].astype(np.float32)).to(dev)
        yb = torch.from_numpy(ytr[idx]).long().to(dev)
        xb = augment(xb) * random_mask(len(idx))                       # lead dropout: missing leads are zeros
        loss = F.cross_entropy(model(xb), yb, weight=w, label_smoothing=0.05)
        opt.zero_grad(); loss.backward(); opt.step()
        if sched.last_epoch < sched.total_steps - 1: sched.step()
        with torch.no_grad():
            for pe, p in zip(ema.parameters(), model.parameters()): pe.mul_(0.99).add_(p.detach(), alpha=0.01)
            for be, b_ in zip(ema.buffers(), model.buffers()): be.copy_(b_)
        tot += loss.item() * len(idx)
        if (i // bs) % 20 == 0: print(f"  batch {i//bs}/{len(perm)//bs} loss {loss.item():.3f}", flush=True)
    a = {n: roc_auc_score(y[va], predict(ema, X[va], n), multi_class="ovr", average="macro") for n in ("II only", "all 12 leads")}
    score = (a["II only"] + a["all 12 leads"]) / 2
    print(f"ep {ep+1:02d}/{epochs} loss {tot/len(perm):.4f} val AUC: II only {a['II only']:.4f} | all12 {a['all 12 leads']:.4f} | best {best:.4f} | {(time.time()-t0)/60:.0f} min", flush=True)
    if score > best: best, bad = score, 0; torch.save(ema.state_dict(), "model12.pt"); print("  -> saved model12.pt", flush=True)
    else:
        bad += 1
        if bad >= 5: print("early stop"); break

ema.load_state_dict(torch.load("model12.pt", map_location=dev)); yt = y[te]
print("\n=== TEST (fold 10): same model, different leads available ===")
print(f"{'leads given':14s} | macro AUC | accuracy | Critical AUC | Critical recall (argmax)")
for n in NAMES:
    P = predict(ema, X[te], n); pr = P.argmax(1)
    print(f"{n:14s} | {roc_auc_score(yt, P, multi_class='ovr', average='macro'):9.4f} | {(pr == yt).mean():8.3f} | {roc_auc_score(yt == 2, P[:, 2]):12.4f} | {(pr[yt == 2] == 2).mean():.3f}")
print("\n(reference: dedicated Lead-II-only models gave macro AUC ~0.825, accuracy ~0.665)")
for n in ("II only", "all 12 leads"):
    thr_table(predict(ema, X[va], n), y[va], f"{n} - validation")
    thr_table(predict(ema, X[te], n), yt, f"{n} - test")
