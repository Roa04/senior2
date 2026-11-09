# ThromboGuard – Flutter App (v2)

نسخة معدّلة من التطبيق لتطابق تصميم HTML الذي أرسلته (login, register, onboarding,
home بحالاته الثلاث Normal/Abnormal/Critical, history, profile) — بنفس الألوان
والكروت وشريط التنقل السفلي — وبطبقة بيانات متوافقة مع بنية PTB-XL.

## علاقة التطبيق بـ PTB-XL

https://physionet.org/content/ptb-xl/1.0.3/ هو مجموعة بيانات حقيقية تحتوي أكثر
من 21 ألف تخطيط قلب سريري (12-lead ECG)، كل تسجيل مرفق بحقل `scp_codes`
(أكواد تشخيص معيارية SCP-ECG) مع نسبة الثقة، ومصنّفة ضمن 5 فئات رئيسية:
`NORM`, `MI`, `STTC`, `CD`, `HYP`.

في هذا التطبيق:
- `lib/models/models.dart` → صنف `EcgRecord` مطابق تمامًا لبنية سجل PTB-XL
  (ecg_id, patient_id, sampling rate, scp_codes...).
- `lib/services/ptbxl_service.dart` → يحاكي حاليًا استلام سجلات مصنّفة بنفس
  شكل `scp_codes`، ثم يحوّلها إلى مستوى الخطورة الثلاثي المستخدم بالواجهة:
  - `NORM` → طبيعي (أخضر)
  - `STTC` / `CD` / `HYP` → غير طبيعي (أصفر)
  - `MI` (مثل IMI, ASMI, ILMI...) → حرِج (أحمر)

### لربطه بالنموذج الحقيقي لاحقًا (Senior Project II)

1. درّب مصنّف (مثلاً CNN) على PTB-XL باستخدام حقل `scp_codes` كـ labels،
   وذلك على جهازك/خادم التدريب (خارج التطبيق) باستخدام مكتبة `wfdb` بايثون
   لقراءة الإشارات، و`ptbxl_database.csv` للميتاداتا.
2. انشر النموذج كـ API على السحابة (مثلاً Flask/FastAPI + Docker).
3. في `ptbxl_service.dart`، استبدل الدالة `_fetchNextRecord()` باستدعاء
   HTTPS حقيقي (عبر مكتبة `dio` المذكورة بـ pubspec.yaml) يرسل موجة الـECG
   الواردة من المعصم (AD8232 عبر ESP32/BLE) ويستقبل رد بنفس شكل `scp_codes`.
4. باقي التطبيق (الواجهات، الألوان، منطق `classifyFromScpCodes`) يبقى كما هو
   بدون تعديل، لأنه مبني على شكل الاستجابة نفسه لا على مصدر البيانات.

## كيف تشغّله

```
cd thromboguard_app
flutter pub get
flutter run -d chrome
```

## هيكل المشروع

```
lib/
 ├── main.dart
 ├── theme.dart                      الألوان والخطوط المطابقة لتصميم HTML
 ├── models/models.dart              PatientProfile, EcgRecord (PTB-XL shape), VitalReading
 ├── services/ptbxl_service.dart     محاكاة تصنيف ECG + شرح الربط الحقيقي
 ├── widgets/bottom_nav_shell.dart   الحاوية + شريط التنقل السفلي (Home/History/Profile)
 └── screens/
      ├── login_screen.dart
      ├── register_screen.dart
      ├── onboarding_screen.dart
      ├── home_screen.dart           3 حالات: Normal / Abnormal / Critical
      ├── history_screen.dart
      └── profile_screen.dart
```
