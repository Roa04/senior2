"""ThromboGuard AI server.   run:  uvicorn server:app --host 0.0.0.0 --port 8000
Needs in the same folder: model12.pt, common.py, train.py, alert.py, core.py.   Env: MODEL_PATH, THR_MI, HIGH_TO_CRITICAL."""
import os, numpy as np, torch, torch.nn as nn, torch.nn.functional as F
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from train import ECGNet
import core, advice

LEAD_II = 1                                    # channel order: I, II, III, aVR, aVL, aVF, V1..V6


class Net12(ECGNet):
    def __init__(s):
        super().__init__()
        s.stem = nn.Sequential(nn.Conv1d(12, 32, 15, 2, 7, bias=False), nn.BatchNorm1d(32), nn.ReLU())


_model = Net12(); _model.load_state_dict(torch.load(os.environ.get("MODEL_PATH", "model12.pt"), map_location="cpu")); _model.eval()


def predict_fn(x1000):
    x = torch.zeros(1, 12, 1000); x[0, LEAD_II] = torch.from_numpy(np.asarray(x1000, dtype=np.float32))
    with torch.no_grad(): p = F.softmax(_model(x), 1)[0].numpy()
    return float(p[0]), float(p[1]), float(p[2])


class Profile(BaseModel):
    age: Optional[float] = None; bmi: Optional[float] = None
    smoker: Optional[bool] = None; diabetes: Optional[bool] = None; hypertension: Optional[bool] = None


class AnalyzeIn(BaseModel):
    ecg: List[float]
    sampling_rate: int = 250
    heart_rate: Optional[float] = None
    spo2: Optional[float] = None                # NEW (app must send it)
    fall_detected: bool = False
    profile: Optional[Profile] = None           # accepted, not used (age/sex gave no gain in our experiments)


class AdviceIn(BaseModel):
    level: str = "abnormal"
    heart_rate: Optional[float] = None
    spo2: Optional[float] = None
    lang: str = "ar"
    profile: Optional[Profile] = None


app = FastAPI(title="ThromboGuard AI")


@app.get("/health")
def health(): return {"ok": True, "thr_mi": core.alert.THR_MI, "high_to_critical": core.HIGH_TO_CRITICAL}


@app.post("/analyze")
def analyze(body: AnalyzeIn):
    try: return core.analyze(body.model_dump(), predict_fn)
    except core.BadSignal as e: raise HTTPException(status_code=422, detail=f"Poor ECG signal: {e}")


@app.post("/advice")
def get_advice(body: AdviceIn):
    """Advice for the medium (yellow) state. LLM if ANTHROPIC_API_KEY is set, otherwise (or on any failure) a fixed safe template."""
    return advice.make_advice(body.model_dump())
