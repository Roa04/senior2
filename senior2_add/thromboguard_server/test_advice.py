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
