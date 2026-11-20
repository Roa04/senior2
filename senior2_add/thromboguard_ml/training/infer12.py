"""Inference (Lead II only). Returns the MI score used by the app: mi_score = P(MI)/(P(Normal)+P(MI)).
usage: from infer12 import classify; classify(raw_lead2, fs_in=250)"""
import os, numpy as np, torch, torch.nn as nn, torch.nn.functional as F
from common import preprocess
from train import ECGNet
import alert
LEAD_II = 1   # channel order: I, II, III, aVR, aVL, aVF, V1..V6

class Net12(ECGNet):
    def __init__(s):
        super().__init__()
        s.stem = nn.Sequential(nn.Conv1d(12, 32, 15, 2, 7, bias=False), nn.BatchNorm1d(32), nn.ReLU())

_model = Net12(); _model.load_state_dict(torch.load(os.environ.get("MODEL_PATH", "model12.pt"), map_location="cpu")); _model.eval()

def classify(raw_lead2, fs_in=250):
    x = torch.zeros(1, 12, 1000)
    x[0, LEAD_II] = torch.from_numpy(preprocess(raw_lead2, fs_in))
    with torch.no_grad():
        p = F.softmax(_model(x), 1)[0].numpy()
    s = alert.mi_score(p[0], p[2])
    return {"mi_score": s, "is_mi": s >= alert.THR_MI, "probs": [float(v) for v in p]}
