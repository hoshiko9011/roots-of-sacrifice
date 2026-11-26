# راهنمای ساخت و نصب اندروید

این راهنما نصب نسخهٔ منتشرشده و بازسازی APK بازی **ریشه‌های ایثار** را شرح می‌دهد. معرفی پروژه در [README](../README.md) آمده است.

## نسخهٔ منتشرشده

نسخهٔ `1.0.0` (`versionCode=1`) از [صفحهٔ Release](https://github.com/hoshiko9011/roots-of-sacrifice/releases/tag/v1.0.0) قابل دریافت است.

- [دانلود APK امضاشده](https://github.com/hoshiko9011/roots-of-sacrifice/releases/download/v1.0.0/roots-of-sacrifice-release.apk)
- نام بسته: `ir.roots_of_sacrifice.game`
- حداقل اندروید: API 24 / اندروید ۷
- اندروید هدف: API 36
- معماری‌ها: `arm64-v8a` و `armeabi-v7a`
- امضا: APK Signature Scheme v2 و v3
- هیچ مجوزی، از جمله اینترنت، در manifest نهایی ثبت نشده است
- حجم: ۷۹٬۵۳۰٬۱۱۰ بایت
- SHA-256:

```text
7a8cd05a6726d9288d00968187540cd19b0f8d7de96407cd675c05d27a6f3e25
```

اگر پروژه را خودتان بسازید، خروجی‌های امضاشده در `builds/android/` نوشته می‌شوند. این پوشه در مخزن نیست و هش بالا فقط برای APK منتشرشده معتبر است.

## نصب روی دستگاه

پیش‌نیازها:

1. فعال بودن USB debugging در دستگاه
2. نصب Android SDK Platform Tools روی رایانه
3. پذیرش درخواست اجازهٔ دیباگ USB روی دستگاه

از ریشهٔ پروژه، APK منتشرشده یا خروجی محلی را نصب کنید:

```bash
adb devices -l
adb install -r builds/android/roots-of-sacrifice-release.apk
```

اگر `adb` در PATH نیست، از `$ANDROID_SDK/platform-tools/adb` استفاده کنید. برای اجرای بازی پس از نصب:

```bash
adb shell monkey -p ir.roots_of_sacrifice.game -c android.intent.category.LAUNCHER 1
```

اگر نسخه‌ای با کلید امضای متفاوت از قبل نصب باشد، اندروید نصب را رد می‌کند. در آن حالت ابتدا از دادهٔ بازی پشتیبان بگیرید و فقط با آگاهی از حذف ذخیرهٔ محلی، نسخهٔ قبلی را حذف کنید. کلید release را بدون برنامه تغییر ندهید؛ نسخه‌های بعدی باید با همان کلید امضا شوند.

نصب مستقیم فایل APK روی خود دستگاه هم ممکن است. اجازهٔ نصب از منابع ناشناخته را فقط برای مدیر فایل مورد اعتماد فعال کنید.

## بازسازی با اسکریپت

اسکریپت [tools/build_android.sh](../tools/build_android.sh) پروژه را import و export می‌کند، APKهای debug و release را تراز و امضا می‌کند، خروجی را بررسی می‌کند و گزارش‌ها و SHA-256 را در `builds/test-results/` می‌نویسد.

### پیش‌نیازها

- Godot Engine 4.7.2 stable
- قالب صادرات رسمی Godot 4.7.2 (در ویندوز معمولاً در `%APPDATA%\Godot\export_templates\4.7.2.stable`)
- JDK 21
- Android SDK با Build Tools `36.0.0` و Platform Tools
- `bash` و `unzip`

Node.js فقط برای تولید مجدد SVG و WAV لازم است، نه برای ساخت APK.

### اجرای اسکریپت

مسیر ابزارها را با متغیرهای محیطی تنظیم کنید. مقادیر پیش‌فرض اسکریپت مربوط به یک محیط محلی ویندوز است و در مخزن نیست:

```bash
export GODOT_BIN="/path/to/godot"
export JDK_HOME="/path/to/jdk-21"
export ANDROID_SDK="/path/to/android-sdk"
export ANDROID_BUILD_TOOLS="/path/to/android-sdk/build-tools/36.0.0"
./tools/build_android.sh
```

اسکریپت به‌صورت پیش‌فرض ابزارهای ویندوزی (`aapt2.exe`، `apksigner.bat`، `zipalign.exe` و `jar.exe`) را صدا می‌زند. روی سیستم‌عامل دیگر باید مسیرها و در صورت نیاز نام فایل ابزارها را با محیط خود هماهنگ کنید.

خروجی نهایی:

```text
builds/android/roots-of-sacrifice-debug.apk
builds/android/roots-of-sacrifice-release.apk
```

### کلیدهای امضا

اسکریپت از این فایل‌های محلی استفاده می‌کند:

```text
builds/keystore/debug.keystore
builds/keystore/release.keystore
builds/keystore/release-password.txt
```

- نام مستعار debug: `androiddebugkey` (رمز استاندارد: `android`)
- نام مستعار release: `roots_of_sacrifice`
- رمز release فقط از فایل محلی خوانده می‌شود و در خروجی فرمان چاپ نمی‌شود
- پوشهٔ `builds/` و keystoreها در `.gitignore` هستند و نباید به مخزن عمومی اضافه شوند
- از `release.keystore` و `release-password.txt` نسخهٔ پشتیبان امن نگه دارید؛ از دست دادن یا تغییر آن‌ها به‌روزرسانی نصب‌های موجود را مختل می‌کند

## بررسی دستی خروجی

اگر بخواهید APK را جدا از اسکریپت بررسی کنید:

```bash
AAPT2="$ANDROID_BUILD_TOOLS/aapt2"
APKSIGNER="$ANDROID_BUILD_TOOLS/apksigner"
ZIPALIGN="$ANDROID_BUILD_TOOLS/zipalign"

"$AAPT2" dump badging builds/android/roots-of-sacrifice-release.apk
"$AAPT2" dump permissions builds/android/roots-of-sacrifice-release.apk
"$APKSIGNER" verify --verbose --print-certs builds/android/roots-of-sacrifice-release.apk
"$ZIPALIGN" -c -p 4 builds/android/roots-of-sacrifice-release.apk
sha256sum builds/android/roots-of-sacrifice-release.apk
```

روی ویندوز نام ابزارها معمولاً `aapt2.exe`، `apksigner.bat` و `zipalign.exe` است. خروجی `dump permissions` باید فقط نام بسته را نشان دهد و هیچ `uses-permission` یا مجوز اینترنت نداشته باشد:

```text
package: ir.roots_of_sacrifice.game
```

## وضعیت آزمون

نسخهٔ release تاکنون فقط روی **Poco X7 Pro** (مدل `2412DPC0AG`، اندروید ۱۶) به‌صورت فیزیکی نصب و اجرا شده است. سازگاری با همهٔ گوشی‌ها ادعا نمی‌شود. جزئیات بیشتر در [README](../README.md) و [گزارش آزمون](TEST_REPORT.md) آمده است.
