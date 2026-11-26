# راهنمای ساخت و نصب اندروید

این راهنما برای بازی **ریشه‌های ایثار** و خروجی‌های تأییدشدهٔ روز ۲۰۲۶-۱۱-۲۶ نوشته شده است.

## خروجی‌های آماده

| فایل | کاربرد | اندازه | SHA-256 |
| --- | --- | ---: | --- |
| `builds/android/roots-of-sacrifice-release.apk` | نسخهٔ نهایی و امضاشده | ۷۹٬۵۳۰٬۱۰۸ بایت | `b55120d90b60d8f4d8a7c128d719e623973cb1f9e7f4abdda8064775564478fc` |
| `builds/android/roots-of-sacrifice-debug.apk` | نسخهٔ اشکال‌زدایی و امضاشده | ۸۴٬۷۳۶٬۵۱۶ بایت | `d87203384c200a193352f3c1f7337ad767bf14c56cc703dc0168e89f5a3ad6a3` |

مشخصات مشترک:

- نام بسته: `ir.roots_of_sacrifice.game`
- نسخه: `1.0.0`، `versionCode=1`
- حداقل اندروید: API 24
- اندروید هدف: API 36
- معماری‌ها: `arm64-v8a` و `armeabi-v7a`
- مجوز `android.permission.INTERNET`: ندارد
- امضا: APK Signature Scheme v2 و v3
- بازی تمام فونت، تصویر، صدا و داده‌های لازم را درون بسته دارد و برای اجرا به اینترنت نیاز ندارد.

## نصب روی دستگاه فیزیکی

پیش‌نیازها:

1. فعال بودن **USB debugging** در دستگاه.
2. نصب **Android SDK Platform Tools** روی رایانه.
3. پذیرش درخواست Authorization دیباگ USB روی دستگاه.

در Git Bash، از ریشهٔ پروژه:

```bash
C:/Users/Yasamin/.evolab-toolchain/sdk/platform-tools/adb.exe devices -l
C:/Users/Yasamin/.evolab-toolchain/sdk/platform-tools/adb.exe install -r builds/android/roots-of-sacrifice-release.apk
```

برای اجرای بازی پس از نصب:

```bash
C:/Users/Yasamin/.evolab-toolchain/sdk/platform-tools/adb.exe shell monkey -p ir.roots_of_sacrifice.game -c android.intent.category.LAUNCHER 1
```

اگر نسخه‌ای با کلید امضای متفاوت قبلاً نصب شده باشد، اندروید نصب را رد می‌کند. در آن حالت ابتدا از دادهٔ بازی پشتیبان بگیرید و فقط با آگاهی از حذف ذخیرهٔ محلی، نسخهٔ قبلی را حذف کنید. کلید release نباید بدون برنامه‌ریزی تغییر کند، زیرا نسخه‌های بعدی باید با همان کلید امضا شوند.

نصب از فایل APK در خود دستگاه نیز ممکن است؛ برای آن باید اجازهٔ نصب از منابع ناشناخته را فقط برای مدیر فایل مورد اعتماد فعال کنید.

## بازسازی با اسکریپت

اسکریپت [tools/build_android.sh](../tools/build_android.sh) مراحل زیر را به‌ترتیب انجام می‌دهد:

1. reimport پروژهٔ Godot و بررسی وجود ۱۵ نمونهٔ WAV imported و چهار MP3 imported.
2. خروجی‌گیری debug و release.
3. کپی binary XML معتبر `icon.xml` تولیدشدهٔ Godot به `themed_icon.xml` مورد انتظار جدول منابع قالب Godot 4.7.2.
4. اجرای `zipalign`.
5. امضا با کلید debug یا release.
6. بررسی امضا، تراز بسته، نام بسته، نسخه، API 24/36، GLES3، ABI، نبود مجوز اینترنت و وجود دادهٔ بازی (`assets.sparsepck` و اسکریپت اصلی) در APK.
7. نوشتن گزارش‌های خام و checksum در `builds/test-results/`.

### پیش‌نیازهای بازسازی

- Godot Engine 4.7.2 stable.
- Export Template رسمی Godot 4.7.2 در مسیر استاندارد Godot:
  - ویندوز: `%APPDATA%\Godot\export_templates\4.7.2.stable`
- JDK 21.
- Android SDK با Build Tools `36.0.0` و Platform Tools.
- Git Bash و ابزار `unzip`.
- Node.js فقط در صورتی که می‌خواهید دارایی‌های SVG را دوباره تولید کنید.

### مسیرهای پیش‌فرض این محیط

```text
Godot: tools/Godot_v4.7.2-stable_win64_console.exe
JDK: C:/Users/Yasamin/.evolab-toolchain/jdk-21.0.13.1+2
Android SDK: C:/Users/Yasamin/.evolab-toolchain/sdk
Build Tools: C:/Users/Yasamin/.evolab-toolchain/sdk/build-tools/36.0.0
```

روی رایانهٔ دیگر مسیرها را با متغیرهای محیطی تنظیم کنید:

```bash
export GODOT_BIN="/path/to/godot_console.exe"
export JDK_HOME="/path/to/jdk-21"
export ANDROID_SDK="/path/to/android-sdk"
export ANDROID_BUILD_TOOLS="/path/to/android-sdk/build-tools/36.0.0"
./tools/build_android.sh
```

### کلیدهای امضا

اسکریپت از این فایل‌ها استفاده می‌کند:

```text
builds/keystore/debug.keystore
builds/keystore/release.keystore
builds/keystore/release-password.txt
```

- نام مستعار debug: `androiddebugkey`
- نام مستعار release: `roots_of_sacrifice`
- رمز debug استاندارد: `android`
- رمز release فقط از فایل محلی خوانده می‌شود و در خروجی فرمان نمایش داده نمی‌شود.
- `builds/` در `.gitignore` قرار دارد و نباید به مخزن عمومی منتقل شود.
- از `release.keystore` و `release-password.txt` نسخهٔ پشتیبان امن و جداگانه نگه دارید. از دست دادن آن‌ها امکان به‌روزرسانی نصب‌های موجود را از بین می‌برد.

## بررسی دستی خروجی

```bash
AAPT2=C:/Users/Yasamin/.evolab-toolchain/sdk/build-tools/36.0.0/aapt2.exe
APKSIGNER=C:/Users/Yasamin/.evolab-toolchain/sdk/build-tools/36.0.0/apksigner.bat
ZIPALIGN=C:/Users/Yasamin/.evolab-toolchain/sdk/build-tools/36.0.0/zipalign.exe

"$AAPT2" dump badging builds/android/roots-of-sacrifice-release.apk
"$AAPT2" dump permissions builds/android/roots-of-sacrifice-release.apk
"$APKSIGNER" verify --verbose --print-certs builds/android/roots-of-sacrifice-release.apk
"$ZIPALIGN" -c -p 4 builds/android/roots-of-sacrifice-release.apk
sha256sum builds/android/roots-of-sacrifice-release.apk
```

خروجی `dump permissions` باید فقط نام بسته را نشان دهد و هیچ `uses-permission` یا مجوز اینترنت نداشته باشد.

## وضعیت آزمون دستگاه

نسخهٔ release روی Poco X7 Pro مدل `2412DPC0AG` با Android 16 و GPU Mali-G720 با `adb install -r` نصب شد. بازی جدید و اجرای دوبارهٔ ذخیرهٔ قبلی بدون کرش و بدون خطای Godot انجام شد؛ `AudioTrack` نیز صدا را راه‌اندازی کرد. Samsung/Huawei فیزیکی، armv7، Adreno/PowerVR، تماس واقعی، Home/خاموشی صفحه و چرخش دستی هنوز آزموده نشده‌اند. emulator Samsung موجود در این محیط پاسخ adb را نداد و به‌عنوان شاهد قبول ثبت نشد.
