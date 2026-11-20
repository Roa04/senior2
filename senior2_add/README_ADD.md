# إضافات ThromboGuard (نورمال أو MI)

## المجلدات
- `thromboguard_ml/training/` : تدريب وتقييم النموذج (PTB-XL، تقسيم حسب المريض strat_fold)
- `thromboguard_server/` : سيرفر FastAPI + نصائح AI + اختبارات
- `ThromboGuard_Colab.ipynb` : تدريب كامل على Colab

## تشغيل السيرفر (على اللابتوب)
```
cd thromboguard_server
pip install -r requirements_server.txt
python test_core.py
set MODEL_PATH=model12.pt
uvicorn server:app --host 0.0.0.0 --port 8000
```
(ملف model12.pt ينتج من التدريب، مش مرفوع على GitHub)

## التدريب (محلي)
```
cd thromboguard_ml/training
python prepare_data12.py ..\ptbxl\ptb-xl-a-large-publicly-available-electrocardiography-dataset-1.0.3
python prepare_data.py   ..\ptbxl\ptb-xl-a-large-publicly-available-electrocardiography-dataset-1.0.3
python train12.py 12 8000
python mi_check.py
```
ملاحظة: النتائج المعتمدة فقط من هذا التقسيم (حسب المريض). دفاتر Keras القديمة تستخدم تقسيم عشوائي = تسريب، لا تُستخدم بالتقرير.
