# البيان — مصحف المتشابهات

مصحف المدينة كاملًا (604 صفحات بخطوط مجمع الملك فهد QCF V2، سطرًا بسطر كما في المطبوع)،
مع إبراز مواضع التشابه بالتلوين أو بعلامات في الهامش، والتنقل بين المواضع ثم العودة للصفحة الأصلية.

## التشغيل

```bash
pip install fonttools
python3 tool/build_data.py     # يجلب المصادر ويولّد assets/ ويتحقق منها
flutter create . --platforms=android,ios --org sa.albayan --project-name albayan
flutter run
```

البناء الآلي: كل دفع إلى `main` يبني نسخة أندرويد (APK) في GitHub Actions.

## المصادر

- تخطيط الصفحات: https://github.com/zonetecde/mushaf-layout
- خطوط المصحف QCF V2: https://github.com/nuqayah/qpc-fonts
- المتشابهات (CC0): https://github.com/Waqar144/Quran_Mutashabihat_Data
- خطوط الواجهة (OFL): Cairo والرقعة من https://github.com/google/fonts
