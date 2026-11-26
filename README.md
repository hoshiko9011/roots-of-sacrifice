# ریشه‌های ایثار / Roots of Sacrifice

بازی دوبعدی پیکسل‌آرت، فارسی و کاملاً آفلاین برای اندروید؛ ساخته‌شده با Godot 4.7.2 توسط گروه **نیوتک / NewTech**.

بازیکن در شهر تخیلی «نوبهار» باغی فراموش‌شده را احیا می‌کند، نهال می‌کارد، آب و خاک را مدیریت می‌کند، با همسایه‌ها همکاری می‌کند، روایت‌های مستند را می‌شنود و پیام‌های یادبود می‌نویسد. بازی شامل هشت فصل، ۳۰ مأموریت، ۱۷ پرسش، شش درخت بومی ایران و ۳۲ روایت NPC است.

نسخهٔ `1.0.0` (`versionCode=1`) در [Releases](https://github.com/hoshiko9011/roots-of-sacrifice/releases/tag/v1.0.0) منتشر شده است.

## دانلود

- [دانلود APK امضاشدهٔ نسخهٔ ۱.۰.۰](https://github.com/hoshiko9011/roots-of-sacrifice/releases/download/v1.0.0/roots-of-sacrifice-release.apk)
- نام بسته: `ir.roots_of_sacrifice.game`
- حجم: ۷۹٬۵۳۰٬۱۱۰ بایت
- SHA-256:

```text
7a8cd05a6726d9288d00968187540cd19b0f8d7de96407cd675c05d27a6f3e25
```

## مشخصات فنی

| مورد | مقدار |
| --- | --- |
| موتور | Godot 4.7.2 (GDScript) |
| پلتفرم | اندروید، تک‌نفره، آفلاین، افقی |
| وضوح پایه | ۱۲۸۰×۷۲۰ |
| رندر | GL Compatibility / GLES3 |
| معماری | `arm64-v8a` و `armeabi-v7a` |
| حداقل اندروید | API 24 / اندروید ۷ |
| اندروید هدف | API 36 |
| فونت | Vazirmatn (مجوز OFL) |
| ذخیره | محلی، مسیر `user://` |
| مجوز اندروید | هیچ مجوزی در manifest نهایی ثبت نشده است |

## قابلیت‌ها

- هشت فصل با مأموریت، پاداش و پایان فصل
- چهار منطقهٔ قابل‌بازدید (باغ، مدرسه، پارک محله و شهر سبز)؛ هر منطقه شش بستر کاشت دارد
- آماده‌سازی خاک، کاشت، آبیاری، کمپوست و رشد روزانهٔ نهال
- چرخهٔ خودکار روز و شب با مدت قابل‌تنظیم از ۲ تا ۸ دقیقه
- جمع‌آوری پسماند، بازیافت، کمک به NPC و تنوع زیستی
- نقشهٔ فصل‌ها و بازدید از مکان‌های بازشده
- ۳۲ روایت شخص‌اول برای چهار NPC؛ ۲۴ روایت مستند و هشت روایت تخیلی (با برچسب مشخص)
- ثبت نام و پیام یادبود روی نهال‌های کاشته‌شده
- ۱۷ پرسش آموزشی و ۱۱ دستاورد
- کنترل لمسی (جوی‌استیک، دکمه‌های «عمل» و «آب») و معادل صفحه‌کلید
- رابط فارسی RTL، ارقام فارسی، و تنظیمات موسیقی، صدا، مدت روز، کنترل لمسی و کاهش حرکت
- ذخیرهٔ خودکار، ذخیرهٔ دستی، نسخهٔ پشتیبان و ادامه از صفحهٔ اصلی
- آموزش اولیه و راهنما

مقادیر نیاز آب، نور و رشد گونه‌ها برای تعادل بازی‌اند و توصیهٔ کشاورزی واقعی نیستند. آدرس منابع روایت‌های مستند فقط به‌صورت متنی در داده‌ها آمده‌اند و بازی آن‌ها را باز یا از اینترنت دریافت نمی‌کند.

## کنترل‌ها

| عمل | لمسی | صفحه‌کلید |
| --- | --- | --- |
| حرکت | جوی‌استیک پایین چپ | `WASD` یا کلیدهای جهت‌دار |
| تعامل و گفت‌وگو | لمس هدف یا دکمهٔ «عمل» | `E` یا `Space` |
| آبیاری | دکمهٔ «آب» یا دکمهٔ کنار نهال | `Q` |
| توقف | دکمهٔ «توقف» | `Escape` |
| بازگشت اندروید | دکمهٔ Back سیستم | بستن مودال، توقف یا تأیید خروج |

## اجرا و ساخت

### پیش‌نیازها

- Godot Engine 4.7.2 stable
- برای خروجی اندروید: قالب صادرات رسمی Godot 4.7.2، JDK 21، Android SDK Build Tools `36.0.0` و `unzip`
- Node.js فقط اگر بخواهید SVG و WAV را دوباره تولید کنید

### اجرای دسکتاپ

مخزن را clone کنید، فایل `project.godot` را در Godot 4.7.2 باز کنید و اجرا کنید. از خط فرمان:

```bash
godot --path .
```

### اجرای تست‌ها

```bash
godot --headless --path . --scene res://tests/test_runner.tscn
```

خروجی مورد انتظار: `ROOTS_TESTS: 325 checks, 0 failures`.

### ساخت APK

اسکریپت `tools/build_android.sh` پروژه را import و export می‌کند، APK را تراز و امضا می‌کند و خروجی را بررسی می‌کند. مسیر ابزارها را با متغیرهای محیطی تنظیم کنید؛ مقادیر پیش‌فرض اسکریپت مربوط به یک محیط محلی ویندوز است و در مخزن نیست:

```bash
export GODOT_BIN="/path/to/godot"
export JDK_HOME="/path/to/jdk-21"
export ANDROID_SDK="/path/to/android-sdk"
export ANDROID_BUILD_TOOLS="/path/to/android-sdk/build-tools/36.0.0"
./tools/build_android.sh
```

فایل‌های امضا در مخزن نیستند و باید به‌صورت محلی در این مسیرها قرار گیرند:

```text
builds/keystore/debug.keystore
builds/keystore/release.keystore
builds/keystore/release-password.txt
```

پوشهٔ `builds/` و keystoreها در `.gitignore` هستند. از keystore و رمز release نسخهٔ پشتیبان امن نگه دارید؛ تغییر کلید، به‌روزرسانی نصب‌های موجود را مختل می‌کند.

راهنمای کامل ساخت و نصب: [docs/ANDROID_BUILD.md](docs/ANDROID_BUILD.md).

برای تولید مجدد دارایی‌های ساخته‌شده (تصاویر منبع کاربر و فایل‌های MP3 تغییر نمی‌کنند):

```bash
node tools/generate_art.mjs
node tools/generate_audio.mjs
```

## حریم خصوصی

بازی کاملاً آفلاین است، به اینترنت یا سرور نیاز ندارد و حساب کاربری، تبلیغات، خرید درون‌برنامه‌ای یا ردیابی ندارد. پیشرفت، یادبودها و تنظیمات فقط روی دستگاه ذخیره می‌شوند.

## وضعیت آزمون

تست خودکار منطق بازی، ذخیره، محتوا و بخشی از رابط را پوشش می‌دهد، اما جایگزین بازی دستی روی دستگاه نیست. نسخهٔ release تاکنون فقط روی **Poco X7 Pro** (مدل `2412DPC0AG`، اندروید ۱۶) به‌صورت فیزیکی نصب و اجرا شده است. سازگاری با همهٔ گوشی‌ها، از جمله Samsung و Huawei و معماری `armeabi-v7a`، ادعا نمی‌شود.

در این نسخه ویرایش یا حذف یادبود، انتخاب فصل فعال و تاریخچهٔ تلاش پرسش وجود ندارد.

جزئیات آزمون در [docs/TESTING.md](docs/TESTING.md) و [docs/TEST_REPORT.md](docs/TEST_REPORT.md) آمده است.

## ساختار مخزن

```text
assets/     هنر، صدا و فونت
docs/       معماری، ساخت اندروید، سند طراحی و گزارش آزمون
scenes/     صحنهٔ اصلی (`main.tscn`)
scripts/    منطق بازی، جهان، UI و محتوا
tests/      تست‌های خودکار
tools/      اسکریپت ساخت اندروید و تولید دارایی
project.godot
export_presets.cfg
```

منطق پیشرفت و ذخیره در `GameState` است و `AudioManager` موسیقی و افکت‌ها را مدیریت می‌کند. پوشه‌های `builds/`، `.godot/`، باینری Godot و keystoreها در مخزن نیستند.

## مستندات تکمیلی

- [معماری فنی](docs/ARCHITECTURE.md)
- [راهنمای ساخت و نصب اندروید](docs/ANDROID_BUILD.md)
- [سند طراحی بازی](docs/GDD.md)
- [ماتریس آزمون و پذیرش](docs/TESTING.md)
- [گزارش آزمون](docs/TEST_REPORT.md)
- [Manifest دارایی‌های هنری](assets/art/ASSET_MANIFEST.md)
- [Manifest دارایی‌های صوتی](assets/audio/AUDIO_MANIFEST.md)

## تیم

**نیوتک / NewTech**

- یاسمین رضایی
- یاسمن بخشی‌زاده

فونت Vazirmatn با مجوز OFL در `assets/fonts/OFL.txt` آمده است.

> هر نهال، فرصتی برای ساختن آینده‌ای سبزتر است.t
user://garden.save
user://garden.backup
user://settings.cfg
```

ساختار ذخیره:

```json
{
  "payload": "{\"version\":3,\"chapter\":1,...}",
  "checksum": "<SHA-256 hex>"
}
```

نکات فنی:

- `payload` یک رشتهٔ JSON است و checksum از همان رشته محاسبه می‌شود.
- حداکثر اندازهٔ فایل قابل‌خواندن `2,000,000` بایت است.
- فایل با نسخهٔ موقت نوشته می‌شود، `flush()` می‌شود و سپس با rename جایگزین می‌گردد.
- پیش از جایگزینی ذخیرهٔ عادی، نسخهٔ معتبر قبلی در backup کپی می‌شود.
- اگر ساخت backup شکست بخورد، ذخیرهٔ اصلی جایگزین نمی‌شود.
- checksum، JSON، نسخه، ساختار state و مقادیر اصلی اعتبارسنجی می‌شوند.
- ذخیره‌های نسخهٔ ۱ و ۲ به نسخهٔ ۳ مهاجرت می‌کنند.
- Continue فقط وقتی فعال است که primary یا backup معتبر باشد.
- timer ده‌ثانیه‌ای حالت dirty را ذخیره می‌کند.
- پایان فصل، پایان روز، ایجاد یادبود، نخستین خواندن روایت، بازگشت به منو، pause و close نیز ذخیره را صدا می‌زنند.
- تنظیمات جدا از ذخیرهٔ بازی و در `ConfigFile` ذخیره می‌شوند.

checksum یک سازوکار برای تشخیص تغییر ناخواسته یا خرابی ساده است؛ ذخیره رمزنگاری نشده و این قابلیت را به‌عنوان محافظت ضد-cheat یا امنیت رمزنگاری‌شده معرفی نمی‌کند.

## امنیت، حریم خصوصی و مجوزها

### امنیت اجرای آفلاین

- APK نهایی هیچ `uses-permission` ندارد.
- `aapt2 dump permissions` فقط نام بسته را نشان می‌دهد.
- مجوز `android.permission.INTERNET` وجود ندارد.
- در اسکریپت‌های gameplay هیچ `HTTPRequest`، `HTTPClient`، `Socket`، WebSocket یا سرویس شبکه‌ای وجود ندارد.
- تمام فونت، تصویر، صدا و دادهٔ لازم داخل بسته قرار دارد.
- بازی برای اجرا به اینترنت یا سرور نیاز ندارد.

### حریم خصوصی

- حساب کاربری، ورود، چت، رتبه‌بندی آنلاین و ارسال داده به سرور وجود ندارد.
- تبلیغات، خرید درون‌برنامه‌ای، قمار، لوت‌باکس و ردیابی وجود ندارد.
- پیشرفت بازی، یادبودهای بازیکن و تنظیمات فقط محلی در `user://` ذخیره می‌شوند.
- بازی از دوربین، میکروفون، موقعیت مکانی، مخاطبین، نوتیفیکیشن یا حافظهٔ خارجی مجوز نمی‌گیرد.

### یکپارچگی و امضای بسته

- release با کلید RSA 2048 و Scheme v2/v3 امضا شده است.
- نسخهٔ release پرچم `application-debuggable` ندارد.
- SHA-256 گواهی release:

```text
cc66b06d152fffe334ae588627fcc05ed353256d3b9b7b233fd759026cef0a3c
```

- `zipalign`، `apksigner verify`، badging، permissions و SHA-256 فایل در build script بررسی می‌شوند.
- keystore و رمز release در `.gitignore` قرار دارند و در مخزن یا Release قرار نگرفته‌اند.
- از keystore release باید پشتیبان امن و جداگانه نگه داشته شود؛ تغییر آن نصب به‌روزرسانی روی نسخه‌های موجود را مختل می‌کند.

این موارد شواهد طراحی آفلاین، بررسی manifest و اعتبارسنجی بسته‌اند؛ ادعای یک آزمون نفوذ مستقل یا تضمین امنیت مطلق نیست.

## اصالت دارایی‌ها و مجوز

- بیشتر SVGها با `tools/generate_art.mjs` و به‌صورت deterministic برای این پروژه ساخته شده‌اند.
- ۱۵ WAV با `tools/generate_audio.mjs` و بدون نمونهٔ ثالث تولید شده‌اند.
- چهار MP3 توسط صاحب پروژه ارائه و مجوز استفادهٔ آن‌ها تأیید شده است؛ اصالت آن‌ها به‌عنوان آثار تولیدی پروژه ادعا نمی‌شود.
- دو آیکون نهال و تصویر سینمایی `cinematic_garden.png` توسط صاحب پروژه ساخته و ارائه شده‌اند.
- مرجع بصری دکمه‌ها توسط صاحب پروژه با مجوز معتبر ارائه شده است.
- فونت Vazirmatn همراه مجوز OFL در `assets/fonts/OFL.txt` حفظ شده است.
- هیچ شخصیت، نقشه، تصویر، موسیقی یا دارایی proprietary از بازی‌های دیگر کپی نشده است.
- Revenant Earth، New Roots، Stardew Valley، Littlewood، Fields of Mistria، Roots of Pacha و Forager فقط الهام مکانیکی/طراحی بوده‌اند.

جزئیات بیشتر:

- [Manifest هنری](assets/art/ASSET_MANIFEST.md)
- [Manifest صوتی](assets/audio/AUDIO_MANIFEST.md)

## اجرای پروژه

### پیش‌نیاز

- Godot Engine 4.7.2 stable.
- Export Template رسمی Godot 4.7.2 برای خروجی Android.
- Git Bash و `unzip` برای اسکریپت Android.
- JDK 21 و Android SDK Build Tools `36.0.0` برای ساخت APK.
- Node.js فقط برای تولید مجدد SVG و WAV.

### اجرای دسکتاپ

1. Godot 4.7.2 را نصب کنید.
2. این مخزن را clone کنید.
3. `project.godot` را در Godot import و اجرا کنید.
4. برای اجرای مستقیم خط فرمان:

```bash
godot --path .
```

### اجرای تست‌ها

```bash
godot --headless --path . --scene res://tests/test_runner.tscn
```

اگر باینری Godot داخل `tools/` موجود است:

```bash
./tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --scene res://tests/test_runner.tscn
```

نتیجهٔ تأییدشده در ۲۰۲۶-۱۱-۲۶:

```text
ROOTS_TESTS: 325 checks, 0 failures
```

### تولید مجدد دارایی‌ها

```bash
node tools/generate_art.mjs
node tools/generate_audio.mjs
```

تولیدکنندهٔ هنر فقط SVGهای تولیدی و manifest را می‌نویسد و تصاویر منبع کاربر را حفظ می‌کند. تولیدکنندهٔ صدا WAVها را می‌سازد و اعتبارسنجی می‌کند و MP3های ارائه‌شده را تغییر نمی‌دهد.

## ساخت APK اندروید

اسکریپت `tools/build_android.sh` مراحل زیر را انجام می‌دهد:

1. بررسی Godot، JDK، Android SDK، Build Tools، `zipalign`، `apksigner`، `aapt2`، `jar` و `unzip`.
2. import پروژه و بررسی ۱۵ WAV و چهار MP3 imported.
3. export presetهای `Android Debug` و `Android Release`.
4. افزودن `themed_icon.xml` معتبر به APK unsigned.
5. اجرای `zipalign`.
6. امضا با keystore دیباگ یا release.
7. بررسی امضا، alignment، package، SDK، GLES3، ABI، مجوزها و منابع ضروری.
8. نوشتن گزارش‌ها و SHA-256 در `builds/test-results/`.

### مسیرهای پیش‌فرض محیط فعلی

```text
Godot: tools/Godot_v4.7.2-stable_win64_console.exe
JDK: C:/Users/Yasamin/.evolab-toolchain/jdk-21.0.13.1+2
Android SDK: C:/Users/Yasamin/.evolab-toolchain/sdk
Build Tools: C:/Users/Yasamin/.evolab-toolchain/sdk/build-tools/36.0.0
```

روی رایانهٔ دیگر:

```bash
export GODOT_BIN="/path/to/godot_console.exe"
export JDK_HOME="/path/to/jdk-21"
export ANDROID_SDK="/path/to/android-sdk"
export ANDROID_BUILD_TOOLS="/path/to/android-sdk/build-tools/36.0.0"
./tools/build_android.sh
```

### فایل‌های امضای محلی

اسکریپت از این مسیرهای ignored استفاده می‌کند:

```text
builds/keystore/debug.keystore
builds/keystore/release.keystore
builds/keystore/release-password.txt
```

این فایل‌ها در مخزن نیستند. برای ساخت release روی رایانهٔ دیگر باید keystore و رمز معتبر خود را در مسیرهای ignored قرار دهید یا اسکریپت را مطابق محیط تنظیم کنید. رمز release از فایل محلی خوانده و از طریق متغیر محیطی به `apksigner` داده می‌شود؛ در خروجی فرمان چاپ نمی‌شود.

راهنمای کامل در [docs/ANDROID_BUILD.md](docs/ANDROID_BUILD.md) قرار دارد.

## بررسی دستی APK

```bash
AAPT2=/path/to/android-sdk/build-tools/36.0.0/aapt2.exe
APKSIGNER=/path/to/android-sdk/build-tools/36.0.0/apksigner.bat
ZIPALIGN=/path/to/android-sdk/build-tools/36.0.0/zipalign.exe

"$AAPT2" dump badging builds/android/roots-of-sacrifice-release.apk
"$AAPT2" dump permissions builds/android/roots-of-sacrifice-release.apk
"$APKSIGNER" verify --verbose --print-certs builds/android/roots-of-sacrifice-release.apk
"$ZIPALIGN" -c -p 4 builds/android/roots-of-sacrifice-release.apk
sha256sum builds/android/roots-of-sacrifice-release.apk
```

خروجی permissions باید فقط این خط باشد:

```text
package: ir.roots_of_sacrifice.game
```

## ساختار مخزن

```text
.
├── assets/
│   ├── art/          SVGها، atlasها، پس‌زمینه‌ها، shader و manifest
│   ├── audio/        15 WAV، 4 MP3 و manifest صوتی
│   └── fonts/        Vazirmatn و مجوز OFL
├── docs/
│   ├── ARCHITECTURE.md
│   ├── ANDROID_BUILD.md
│   ├── GDD.md
│   ├── TESTING.md
│   └── TEST_REPORT.md
├── scenes/
│   └── main.tscn
├── scripts/
│   ├── data/game_content.gd
│   ├── main.gd
│   ├── game_state.gd
│   ├── world.gd
│   ├── player.gd
│   ├── plot.gd
│   ├── touch_joystick.gd
│   ├── ui_factory.gd
│   ├── atlas.gd
│   └── audio_manager.gd
├── tests/
│   ├── run_tests.gd
│   └── test_runner.tscn
├── tools/
│   ├── build_android.sh
│   ├── generate_art.mjs
│   ├── generate_audio.mjs
│   ├── generate_preview.mjs
│   ├── generate_reference_preview.mjs
│   └── capture_preview.gd
├── export_presets.cfg
├── project.godot
└── .gitignore
```

پوشه‌های `builds/`، `.godot/`، ابزارهای SDK، باینری Godot، keystoreها و خروجی‌های موقت در مخزن commit نمی‌شوند.

## پوشش تست خودکار

تست فعلی شامل این حوزه‌هاست:

- مقداردهی اولیه، چهار منطقه، شش بستر هر منطقه و هشت فصل.
- تکمیل هر ۳۰ مأموریت از طریق APIهای واقعی و جلوگیری از پایان تکراری.
- ذخیره، بازیابی، backup، فایل خراب، مهاجرت نسخه‌ها و Continue.
- چرخهٔ روز، هوا، رطوبت، خاک، سلامت، رشد، مرگ و کاشت دوباره.
- کمپوست، آب‌پاش، پسماند، کمک به NPC و تنوع زیایی.
- ۱۷ پرسش، شش گونه، ۳۲ روایت و ۱۱ دستاورد.
- بارگذاری ۱۵ WAV، چهار MP3 و ۶۰ فایل تصویری runtime.
- UI smoke منو، جهان، مودال‌ها، تنظیمات، راهنما، توقف، ذخیره، ending و Continue.
- RTL و راست‌چین بودن متن‌های صفحه‌های کلیدی.
- رفتار توقف در Settings، Android Back در سطح کد، focus صدا و reset جوی‌استیک.
- نبود هم‌پوشانی کارت آموزش با دکمه‌های «عمل» و «آب».
- شش بستر قابل‌دسترسی در هر هشت صحنه و برخورد صحیح اشیا.

محدودیت مهم: UI smoke عمدتاً نمونه‌ها را با فراخوانی مستقیم متد می‌سازد و جایگزین لمس دستی یا پیمایش کامل دستگاه نیست. ماتریس کامل در [docs/TESTING.md](docs/TESTING.md) و گزارش نهایی در [docs/TEST_REPORT.md](docs/TEST_REPORT.md) قرار دارد.

## محدودیت‌های صادقانه

- فقط Poco X7 Pro تست فیزیکی شده است.
- Samsung و Huawei تست فیزیکی نشده‌اند.
- armv7، Adreno و PowerVR تست فیزیکی نشده‌اند.
- لمس فیزیکی همهٔ دکمه‌ها، Android Back، چرخش صفحه، تماس، Home/خاموشی و ANR هنوز روی دستگاه تأیید نشده‌اند.
- عملکرد طولانی‌مدت، FPS، حافظه و دما اندازه‌گیری نشده‌اند.
- قوانین رسمی مسابقه در دسترس نبوده و انطباق رسمی ادعا نمی‌شود.
- ویدئوی فشرده تولید نشده؛ حرکت سینمایی با shader زمان‌واقعی پیاده‌سازی شده است.
- ویرایش یا حذف یادبود، انتخاب فصل فعال، تاریخچهٔ تلاش پرسش و beberapa قابلیت‌های توسعه‌ای در این نسخه وجود ندارند.

## مستندات تکمیلی

- [معماری فنی](docs/ARCHITECTURE.md)
- [راهنمای ساخت و نصب اندروید](docs/ANDROID_BUILD.md)
- [سند طراحی بازی](docs/GDD.md)
- [ماتریس آزمون و پذیرش](docs/TESTING.md)
- [گزارش آزمون](docs/TEST_REPORT.md)
- [Manifest دارایی‌های هنری](assets/art/ASSET_MANIFEST.md)
- [Manifest دارایی‌های صوتی](assets/audio/AUDIO_MANIFEST.md)
