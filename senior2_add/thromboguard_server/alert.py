"""ThromboGuard decision layer. The ECG model answers ONE question: NORMAL or MI.
   mi_score = P(MI) / (P(Normal) + P(MI))   -- exactly the score evaluated in 'MI vs Normal' (Lead II: AUC 0.915, sens 0.80 / spec 0.88 at THR_MI=0.31).
Vital-sign rules are CLINICAL RULES (not trained, not validated on device data). References (verify against the originals):
 [1] ESC STEMI guideline (Eur Heart J 2018;39:119-177) / NSTEMI (2016;37:267-315): oxygen when SpO2 < 90 %.
 [2] NEWS2 (Royal College of Physicians): pulse <=40 or >=131 bpm are the extreme bands."""

THR_MI = 0.31           # chosen on the FULL validation set (Lead II, balanced sens/spec); same value printed by mi_check_conf.py
SPO2_SEVERE = 90        # [1]
HR_LOW_SEVERE, HR_HIGH_SEVERE = 40, 131      # [2]
MOTION_MAX = 1.5        # tune with real MPU6050 data


def mi_score(p_normal, p_critical):
    return float(p_critical) / (float(p_normal) + float(p_critical) + 1e-9)


def decide_alert(score, spo2=None, hr=None, motion=0.0):
    """score = mi_score(...).  Returns {"level","message","reasons"}; level: NORMAL | ATTENTION | HIGH | CRITICAL | UNRELIABLE"""
    reasons = []
    if motion is not None and motion > MOTION_MAX:
        return {"level": "UNRELIABLE", "message": "Too much movement - stay still and measure again.", "reasons": ["motion"]}
    severe = False
    if spo2 is not None and spo2 < SPO2_SEVERE: severe = True; reasons.append(f"SpO2 {spo2:.0f}% < {SPO2_SEVERE}%")
    if hr is not None and (hr <= HR_LOW_SEVERE or hr >= HR_HIGH_SEVERE): severe = True; reasons.append(f"heart rate {hr:.0f} bpm out of safe range")
    mi = score >= THR_MI
    if mi: reasons.append(f"MI-like ECG pattern (score {score:.2f})")
    if mi and severe:
        return {"level": "CRITICAL", "message": "Possible heart attack with abnormal vital signs - send the emergency alert.", "reasons": reasons}
    if mi:
        return {"level": "HIGH", "message": "Possible heart-attack pattern - seek medical care now.", "reasons": reasons}
    if severe:
        return {"level": "ATTENTION", "message": "Abnormal vital signs - recheck and see a doctor if it persists.", "reasons": reasons}
    return {"level": "NORMAL", "message": "No heart-attack pattern detected.", "reasons": reasons}
