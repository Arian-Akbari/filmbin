# فیلم‌بین — اپلیکیشن

بخش موبایل پروژه. برای معماری کلی، راه‌اندازی و پوشش خواسته‌ها، `../README.md` را ببینید.

## اجرا

```bash
flutter pub get
flutter run -d <device> --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

بدون `--dart-define` هم بالا می‌آید؛ مقدار پیش‌فرض همان `http://10.0.2.2:8000/api/v1` است
(یعنی «کامپیوتر میزبان» از دید شبیه‌ساز اندروید).

برای اتصال امن با گواهی سنجاق‌شده:

```bash
flutter run --dart-define=API_BASE_URL=https://10.0.2.2:8443/api/v1 \
            --dart-define=PINNED_CERT_SHA256=<sha256 چاپ‌شده توسط generate_certs.sh>
```

## لایه‌ها

```
lib/
├── core/
│   ├── config/       تنظیمات ساخت (نشانی سرویس، اثر انگشت گواهی)
│   ├── network/      ApiClient روی Dio، میان‌افزارها، خطاهای ترجمه‌شده، سنجاق گواهی
│   ├── storage/      توکن (امن)، آینهٔ sqflite + صندوق خروجی، تنظیمات
│   ├── theme/        تم تیره/روشن، رنگ وضعیت و رنگ نوار پیشرفت
│   └── utils/        قالب‌بندی فارسی و اعتبارسنجی فرم‌ها
├── data/
│   ├── models/       شکل داده‌ها — تنها جایی که JSON دیده می‌شود
│   └── repositories/ یک مخزن برای هر حوزه
├── l10n/             رشته‌های fa/en
└── presentation/
    ├── providers/    حالت برنامه (Riverpod)
    ├── screens/      صفحه‌ها
    ├── widgets/      اجزای مشترک
    └── router.dart   مسیرها (go_router)
```

قاعده‌ها: صفحه‌ها هیچ‌وقت مستقیم `ApiClient` را صدا نمی‌زنند، مخزن‌ها هیچ‌وقت ویجت نمی‌سازند،
و همهٔ عددها از `Formatters` رد می‌شوند تا با ارقام فارسی نمایش داده شوند.

## آزمون‌ها

```bash
flutter test       # ۱۰۶ آزمون: مدل‌ها، شبکه، مخزن‌ها، ویجت‌ها و صفحه‌ها
flutter analyze    # باید بدون هیچ پیامی تمام شود
```

آزمون‌های صفحه‌ها مخزن‌ها را با `mocktail` جایگزین می‌کنند، پس شبکه‌ای در کار نیست و
هر آزمون همان چیزی را می‌سنجد که کاربر می‌بیند.

## آیکون

`assets/icon/foreground.svg` منبع آیکون است. برای ساخت دوبارهٔ خروجی‌ها:

```bash
rsvg-convert -w 432 -h 432 assets/icon/foreground.svg \
  -o android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png
```

(و همین برای بقیهٔ چگالی‌ها: mdpi ۱۰۸، hdpi ۱۶۲، xhdpi ۲۱۶، xxhdpi ۳۲۴.)
