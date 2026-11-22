"""Advice for the MEDIUM (yellow) state. Tries an LLM (Gemini first, else Claude; both optional) and ALWAYS falls back to a fixed safe Arabic template.
The advice is general safety guidance, NOT a diagnosis and NOT medication advice.
Env: GEMINI_API_KEY (+ GEMINI_MODEL), or ANTHROPIC_API_KEY (+ ADVICE_MODEL); ADVICE_TIMEOUT (seconds, default 8). Keys live ONLY in the server environment.
PRIVACY: when the LLM is used, only age/risk-factor flags and HR/SpO2 are sent -- never the name, phone numbers, location or raw ECG."""
import os, json, urllib.request

SYSTEM = ("أنت مساعد داخل جهاز مراقبة قلب (فحص أولي). المستخدم حصل على قراءة تخطيط قلب غير اعتيادية. "
          "اكتب نصائح عربية قصيرة وواضحة (حتى 6 نقاط، أقل من 120 كلمة). القواعد: لا تشخّص ولا تقل إن المستخدم بخير أو مصاب بشيء محدد؛ "
          "لا تذكر أدوية أو جرعات؛ انصح بالراحة والجلوس وعدم القيادة وإخبار شخص قريب ومراجعة طبيب اليوم؛ "
          "اذكر بوضوح علامات الخطر التي تستدعي طلب الإسعاف فوراً (ألم أو ضغط بالصدر، ضيق نفس، تعرق بارد، دوخة أو إغماء، ألم يمتد للذراع أو الفك)؛ "
          "وأكّد أن هذا فحص أولي وليس تشخيصاً. لا تستخدم عناوين ولا تنسيقاً معقداً. "
          "لا تخترع قياسات أو معلومات عن المستخدم أو قدرات للجهاز؛ لا تقل إن رسالة طوارئ أُرسلت أو إن مكالمة أُجريت؛ لا تضعّف أي تنبيه أمان صادر عن النظام؛ "
          "لا تقل إن النتيجة الطبيعية تضمن السلامة؛ النبض فوق 100 أثناء الحركة ليس غير طبيعي تلقائياً. "
          "إذا كانت نسبة الأكسجين أقل من 90% فيجب أن تكون النقطة الأولى: اطلب تقييماً طبياً طارئاً فوراً (الإسعاف)، ولا تنصح بالانتظار لتتحسن النسبة. "
          "لا تذكر دولة معينة أو رقم طوارئ محدد.")

BASE = ("قراءة تخطيط القلب غير اعتيادية (هذا فحص أولي وليس تشخيصاً).\n"
        "• اجلس أو استلقِ بوضع مريح وتوقف عن أي مجهود.\n"
        "• تنفّس ببطء وعمق وحاول أن تهدأ.\n"
        "• لا تقد السيارة بنفسك.\n"
        "• أخبر شخصاً قريباً منك بما حدث.\n"
        "• راجع طبيباً اليوم ولا تؤجل.\n"
        "• إذا ظهر ألم أو ضغط في الصدر، ضيق نفس، تعرّق بارد، دوخة أو إغماء، أو ألم يمتد للذراع أو الفك، فاطلب الإسعاف فوراً.\n"
        "أعد القياس بعد بضع دقائق وأنت ساكن.")


def template_advice(p):
    extra = []
    spo2, hr = p.get("spo2"), p.get("heart_rate")
    if spo2 and spo2 < 94: extra.append(f"• نسبة الأكسجين ({spo2:.0f}%) أقل من المعتاد؛ تأكد أن الحساس ملامس للجلد جيداً وأعد القياس.")
    if hr and (hr > 120 or hr < 50): extra.append(f"• النبض ({hr:.0f}) خارج المعتاد؛ ارتح وأعد القياس.")
    return BASE + ("\n" + "\n".join(extra) if extra else "")


def _user_prompt(p):
    pr = p.get("profile") or {}
    facts = [f"العمر: {pr['age']:.0f}" if pr.get("age") else None,
             "مدخّن" if pr.get("smoker") else None, "سكري" if pr.get("diabetes") else None, "ضغط مرتفع" if pr.get("hypertension") else None,
             f"النبض: {p['heart_rate']:.0f}" if p.get("heart_rate") else None, f"الأكسجين: {p['spo2']:.0f}%" if p.get("spo2") else None]
    return "معلومات المستخدم: " + "، ".join(f for f in facts if f) + ".\nاكتب النصائح الآن."


def gemini_advice(p):
    key = os.environ.get("GEMINI_API_KEY")
    if not key: return None
    model = os.environ.get("GEMINI_MODEL", "gemini-3.5-flash-lite")
    body = json.dumps({"systemInstruction": {"parts": [{"text": SYSTEM}]},
                       "contents": [{"role": "user", "parts": [{"text": _user_prompt(p)}]}],
                       "generationConfig": {"maxOutputTokens": 600}}).encode()
    req = urllib.request.Request(f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent", data=body, method="POST",
                                 headers={"x-goog-api-key": key, "content-type": "application/json"})
    with urllib.request.urlopen(req, timeout=float(os.environ.get("ADVICE_TIMEOUT", "8"))) as r:
        d = json.loads(r.read())
    return "".join(part.get("text", "") for part in d["candidates"][0]["content"]["parts"]).strip()


def claude_advice(p):
    key = os.environ.get("ANTHROPIC_API_KEY")
    if not key: return None
    body = json.dumps({"model": os.environ.get("ADVICE_MODEL", "claude-sonnet-5-5"), "max_tokens": 400, "system": SYSTEM,
                       "messages": [{"role": "user", "content": _user_prompt(p)}]}).encode()
    req = urllib.request.Request("https://api.anthropic.com/v1/messages", data=body, method="POST",
                                 headers={"x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json"})
    with urllib.request.urlopen(req, timeout=float(os.environ.get("ADVICE_TIMEOUT", "8"))) as r:
        text = json.loads(r.read())["content"][0]["text"].strip()
    return text


def llm_advice(p):
    """Gemini if GEMINI_API_KEY is set, else Claude if ANTHROPIC_API_KEY is set, else None (-> template)."""
    if os.environ.get("GEMINI_API_KEY"): return gemini_advice(p)
    return claude_advice(p)


def _trusted(t, p):
    if not (t and 20 <= len(t) <= 1200 and "إسعاف" in t): return False
    spo2 = p.get("spo2")
    if spo2 and spo2 < 90 and "إسعاف" not in t[:200] and "طوارئ" not in t[:200]:   # very low SpO2: emergency must come first
        return False
    return True


def make_advice(p, llm=llm_advice):
    """returns {"advice": str, "source": "llm"|"template"}.  Any LLM problem -> template."""
    try:
        t = llm(p)
        if _trusted(t, p):            # must contain the emergency warning (and first if SpO2 < 90), else we don't trust it
            return {"advice": t, "source": "llm"}
    except Exception:
        pass
    return {"advice": template_advice(p), "source": "template"}
