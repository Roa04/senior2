"""python test_advice.py -- advice logic without network / without an API key."""
import advice
p = dict(level="abnormal", heart_rate=130, spo2=91, profile=dict(age=55, smoker=True))
r = advice.make_advice(p, llm=lambda x: None);               print(r["source"], "|", "إسعاف" in r["advice"], "| spo2/hr lines:", "الأكسجين" in r["advice"], "النبض" in r["advice"])
assert r["source"] == "template" and "إسعاف" in r["advice"]
def boom(x): raise TimeoutError()
assert advice.make_advice(p, llm=boom)["source"] == "template"                                 # LLM failure -> template
assert advice.make_advice(p, llm=lambda x: "نص قصير بدون تحذير كافٍ كي يُقبل")["source"] == "template"   # no emergency warning -> rejected
good = "اجلس وارتح وراجع طبيباً اليوم، وإذا ظهر ألم بالصدر أو ضيق نفس فاطلب الإسعاف فوراً. هذا فحص أولي."
assert advice.make_advice(p, llm=lambda x: good)["source"] == "llm"
pr = advice._user_prompt(p); assert "55" in pr and "مدخّن" in pr and "name" not in pr
print("ALL PASSED")

# --- Gemini provider (no network: urlopen is faked) ---
import io, json as _j, os, urllib.request
class _R:
    def __init__(s, b): s.b = b
    def read(s): return s.b
    def __enter__(s): return s
    def __exit__(s, *a): return False
seen = {}
def fake_urlopen(req, timeout=0):
    seen["url"], seen["key"] = req.full_url, req.headers.get("X-goog-api-key")
    txt = "اجلس وارتح. هذا فحص أولي وليس تشخيصاً. اطلب الإسعاف فوراً إذا ظهر ألم بالصدر أو ضيق نفس أو إغماء."
    return _R(_j.dumps({"candidates": [{"content": {"parts": [{"text": txt}]}}]}).encode())
orig = urllib.request.urlopen; urllib.request.urlopen = fake_urlopen
os.environ["GEMINI_API_KEY"] = "TEST_KEY"; os.environ.pop("ANTHROPIC_API_KEY", None)
r = advice.make_advice(p)
assert r["source"] == "llm" and seen["key"] == "TEST_KEY" and "generativelanguage" in seen["url"], r
# SpO2 < 90: emergency warning not first -> rejected -> template
p2 = dict(p, spo2=85)
long_first = "اجلس وارتح وتنفس ببطء وأعد القياس كل بضع دقائق وأنت ساكن تماماً ولا تقم بأي مجهود. " * 3 + "اطلب الإسعاف فوراً."
assert advice.make_advice(p2, llm=lambda x: long_first)["source"] == "template"
urllib.request.urlopen = orig
os.environ.pop("GEMINI_API_KEY")
print("GEMINI TESTS PASSED")
