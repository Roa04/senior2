"""Build data/X12.npy: all 12 leads of PTB-XL (100 Hz, 10 s), filtered + z-scored per lead. Uses the SAME record order/labels as data/X.npy.
usage: python prepare_data12.py "<PTB-XL folder>" [data_dir]   (needs data/y.npy from prepare_data.py)"""
import sys, os, numpy as np, wfdb
from prepare_data import load_meta
from noise_utils import bandpass_z

ORDER = ["I", "II", "III", "AVR", "AVL", "AVF", "V1", "V2", "V3", "V4", "V5", "V6"]
root = sys.argv[1]; out = sys.argv[2] if len(sys.argv) > 2 else "data"
df = load_meta(root)
y = np.load(f"{out}/y.npy")
assert len(df) == len(y) and np.array_equal(df["label"].values, y), "order/labels differ from data/y.npy - rerun prepare_data.py first"
X = np.zeros((len(df), 12, 1000), np.float16)
for i, (_, r) in enumerate(df.iterrows()):
    sig, meta = wfdb.rdsamp(os.path.join(root, r["filename_lr"]))
    names = [n.upper() for n in meta["sig_name"]]
    x = np.nan_to_num(sig[:, [names.index(n) for n in ORDER]].T.astype(np.float64))      # [12, T]
    if x.shape[1] < 1000: x = np.pad(x, ((0, 0), (0, 1000 - x.shape[1])), mode="edge")
    X[i] = bandpass_z(x[:, :1000])
    if i % 2000 == 0: print(i, "/", len(df), flush=True)
np.save(f"{out}/X12.npy", X)
print("saved", f"{out}/X12.npy", X.shape, X.dtype)
