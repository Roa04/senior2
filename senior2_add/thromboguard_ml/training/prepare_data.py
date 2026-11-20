"""Build X.npy / y.npy / folds.npy from PTB-XL (lead II, 100 Hz, 3 classes).
usage: python prepare_data.py /path/to/ptb-xl-...-1.0.3 [out_dir]
"""
import sys, ast, os
import numpy as np, pandas as pd
from common import LEAD, FS, preprocess

ABNORMAL = {"STTC", "CD", "HYP"}


def make_label(superclasses):
    """MI -> Critical(2); STTC/CD/HYP -> Abnormal(1); NORM only -> Normal(0); else drop (-1)."""
    s = set(superclasses)
    if "MI" in s: return 2
    if s & ABNORMAL: return 1
    if "NORM" in s: return 0
    return -1


def load_meta(root):
    df = pd.read_csv(os.path.join(root, "ptbxl_database.csv"), index_col="ecg_id")
    df["scp_codes"] = df["scp_codes"].apply(ast.literal_eval)
    agg = pd.read_csv(os.path.join(root, "scp_statements.csv"), index_col=0)
    agg = agg[agg["diagnostic"] == 1]
    def to_super(codes):
        return sorted({agg.loc[k, "diagnostic_class"] for k in codes if k in agg.index})
    df["superclasses"] = df["scp_codes"].apply(to_super)
    df["label"] = df["superclasses"].apply(make_label)
    return df[df["label"] >= 0]


def main(root, out="data"):
    import wfdb
    os.makedirs(out, exist_ok=True)
    df = load_meta(root)
    X, y, folds = [], [], []
    for i, (ecg_id, r) in enumerate(df.iterrows()):
        path = os.path.join(root, r["filename_lr"])          # records100
        sig, meta = wfdb.rdsamp(path)
        idx = [n.upper() for n in meta["sig_name"]].index(LEAD)
        X.append(preprocess(sig[:, idx], fs_in=FS))
        y.append(r["label"]); folds.append(r["strat_fold"])
        if i % 2000 == 0: print(i, "/", len(df), flush=True)
    np.save(f"{out}/X.npy", np.stack(X)); np.save(f"{out}/y.npy", np.array(y))
    np.save(f"{out}/folds.npy", np.array(folds))
    print("classes count:", np.bincount(y))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "data")
