# گزارش آزمون ریشه‌های ایثار

- تاریخ: ۲۰۲۶-۱۱-۲۶
- نسخهٔ مورد آزمون: `1.0.0` (`versionCode=1`)
- نام بسته: `ir.roots_of_sacrifice.game`
- موتور: Godot 4.7.2 stable
- محیط ساخت: ویندوز، JDK 21، Android SDK Build Tools 36.0.0

این گزارش نتیجهٔ آزمون‌های اجراشده را خلاصه می‌کند. جزئیات پوشش و معیارهای پذیرش در [آزمون و پذیرش](TESTING.md) آمده است.

## خلاصهٔ نتایج

| حوزه | نتیجه |
| --- | --- |
| تست خودکار منطق، ذخیره و دود UI | قبول: ۳۲۵ بررسی، صفر شکست |
| پیشرفت هشت فصل و ۳۰ مأموریت از طریق API | قبول |
| محتوای بازی (پرسش‌ها، گونه‌ها، روایت‌ها، دستاوردها) | قبول |
| ساخت و بررسی APK امضاشده | قبول؛ بدون مجوز اینترنت |
| نصب روی دستگاه فیزیکی | قبول روی Poco X7 Pro؛ سایر دستگاه‌ها آزموده نشده‌اند |
| لمس فیزیکی، Back دستگاه، عملکرد و جلسهٔ طولانی | آزموده نشده |
| انطباق با قوانین مسابقه | ارزیابی نشده؛ ادعا نمی‌شود |

تست خودکار جایگزین بازی دستی روی دستگاه نیست. سازگاری با همهٔ گوشی‌ها ادعا نمی‌شود.

## تست خودکار

از ریشهٔ پروژه، با Godot 4.7.2:

```bash
godot --headless --path . --scene res://tests/test_runner.tscn
```

خروجی:

```text
ROOTS_TESTS: 325 checks, 0 failures
```

پوشش اصلی:

- بازی تازه، چهار منطقه، شش بستر در هر منطقه، و تکمیل هشت فصل از طریق APIهای `GameState`
- ذخیره، بازیابی، نسخهٔ پشتیبان، رد فایل خراب، و Continue فقط با ذخیرهٔ معتبر
- چرخهٔ روز و شب، مراقبت از نهال، کمپوست و تعامل‌های اصلی جهان
- ۱۷ پرسش، شش درخت بومی، ۳۲ روایت NPC و ۱۱ دستاورد
- بارگذاری دارایی‌های تصویری و صوتی، و دود UI برای منو، جهان، مودال‌ها، تنظیمات، راهنمای ۱۱ مرحله‌ای، توقف و ending
- راست‌چین بودن متن‌های صفحه‌های کلیدی، و مدیریت Android Back در سطح کد

بیشتر بررسی‌های رابط با ساخت صحنه و فراخوانی مستقیم متد انجام شد، نه با لمس یا کلیک واقعی.

### رفع کرش روی Poco X7 Pro

نسخهٔ قبلی روی دستگاه با `SIGSEGV` در `GLThread` متوقف شد. علت، انتخاب فایل MP3 ناموجود به‌جای WAV واردشده و ارسال stream خالی به پخش‌کننده بود. `AudioManager` اکنون وجود منبع را با `ResourceLoader.exists` بررسی می‌کند و stream ناموجود را پخش نمی‌کند. نسخهٔ اصلاح‌شده روی همان دستگاه نصب شد و بازی تازه و ادامه از ذخیره بدون کرش و بدون خطای Godot اجرا شد.

## تولید دارایی

```bash
node tools/generate_art.mjs
```

نتیجه: ۵۵ فایل SVG ساخته و اعتبارسنجی شد و `title_art.png` بدون تغییر ماند. پانزده اثر WAV تولیدی‌اند و چهار آهنگ MP3 توسط صاحب پروژه ارائه شده‌اند.

## بررسی APK

ساخت و امضا با `./tools/build_android.sh` انجام شد. جزئیات ابزارها و نصب در [راهنمای ساخت اندروید](ANDROID_BUILD.md) آمده است.

نسخهٔ منتشرشدهٔ `1.0.0` بررسی شد:

- [APK امضاشده](https://github.com/hoshiko9011/roots-of-sacrifice/releases/download/v1.0.0/roots-of-sacrifice-release.apk)
- حجم: ۷۹٬۵۳۰٬۱۱۰ بایت
- SHA-256: `7a8cd05a6726d9288d00968187540cd19b0f8d7de96407cd675c05d27a6f3e25`
- حداقل اندروید: API 24؛ اندروید هدف: API 36
- معماری‌ها: `arm64-v8a` و `armeabi-v7a`
- امضا: Scheme v2 و v3
- خروجی `dump permissions` فقط نام بسته را نشان می‌دهد و مجوز اینترنت ندارد

خروجی‌های محلی اسکریپت در `builds/android/` نوشته می‌شوند. این پوشه در مخزن نیست و هش بالا فقط برای APK منتشرشده معتبر است.

## وضعیت آزمون دستگاه

نسخهٔ release روی **Poco X7 Pro** (مدل `2412DPC0AG`، اندروید ۱۶) با `adb install -r` نصب شد. بازی تازه و ادامه از ذخیرهٔ قبلی بدون کرش اجرا شد. لمس فیزیکی همهٔ کنترل‌ها، Android Back، چرخش صفحه، Home/خاموشی، تماس واقعی، ANR و عملکرد طولانی‌مدت روی دستگاه تأیید نشده‌اند. سازگاری با Samsung، Huawei، معماری `armeabi-v7a` و سایر گوشی‌ها ادعا نمی‌شود.

چند تصویر رندر دسکتاپ به‌صورت محلی در `tools/ignored/` گرفته شده است. این فایل‌ها در مخزن نیستند و جایگزین آزمون دستگاه نیستند.

## موارد باز

- مسیر طبیعی هشت فصل با ورودی لمسی هنوز انجام نشده است
- اندازه‌گیری FPS، حافظه و جلسهٔ طولانی انجام نشده است
- انطباق رسمی با قوانین مسابقه بررسی نشده است

ویرایش یا حذف یادبود در این نسخه وجود ندارد و نباید در پذیرش ادعا شود. جملهٔ کاربرد کوتاه برای هر شش گونه.
- حذف دکمه‌های راهنما/روایت از دیالوگ NPC و پرسش از HUD؛ حفظ دسترسی به پرسش و روایت در منوی مأموریت‌های مرتبط.
- وجود ۱۵ WAV معتبر، بارگذاری چهار MP3 و انتخاب آهنگ مناسب برای باغ، مدرسه، پارک، شهر، شب و باران.

پاسخ اشتباه به پرسش به‌عنوان پاسخ حل‌شده ثبت نمی‌شود؛ پاسخ درست امتیاز فرهنگ و پیشرفت مأموریت مربوط را ثبت می‌کند. دود UI صحنه‌ها را واقعاً می‌سازد و متدهای مسیر تعامل را صدا می‌زند، اما بررسی بصری یا لمس دستی هر کنترل را جایگزین نمی‌کند.

### علت و رفع کرش Poco X7 Pro

لاگ فیزیکی نسخهٔ قبلی `SIGSEGV` در `GLThread` و پیش از آن `No loader found for res://assets/audio/sfx_click.mp3` ثبت کرد. در خروجی Godot، WAVها به `.sample` imported تبدیل می‌شوند و `FileAccess.file_exists` نام منبع را پیدا نمی‌کرد؛ کد به‌اشتباه MP3 ناموجود را انتخاب می‌کرد و stream خالی به پخش‌کننده می‌داد. اکنون `AudioManager` از `ResourceLoader.exists` استفاده می‌کند، stream ناموجود را به پخش‌کننده نمی‌دهد و تست‌های WAV/MP3/loop آن را پوشش می‌دهند. نسخهٔ اصلاح‌شده روی Poco نصب، بازی جدید و ذخیرهٔ قبلی اجرا و لاگ `poco-final-gameplay.log` بدون خطای Godot تأیید شد.

## تولید هنری

فرمان:

```bash
node tools/generate_art.mjs
```

نتیجه:

```text
Generated 55 SVG files
Validated 55 SVG files and manifest; title_art.png preserved.
```

اعتبارسنجی شامل XML، ابعاد، viewBox، پالت، پوشش سلول‌های atlas، هشت‌بودن صحنه‌های فصل، وجود metadata دادگاه کاشت رزروشده، نبود تصویر/متن خارجی و حفظ checksum تصویر عنوان است. پانزده اثر صوتی WAV تولیدی و بدون نمونهٔ ثالث‌اند؛ چهار آهنگ MP3 با اجازهٔ صاحب پروژه ارائه شده‌اند و در `assets/audio/AUDIO_MANIFEST.md` جداگانه ثبت می‌شوند.

## بررسی APK

وضعیت فعلی: در ۲۰۲۶-۱۱-۲۶ و به درخواست صاحب پروژه، هر دو APK از منبع فعلی دوباره ساخته، امضا و بررسی شدند. مقادیر زیر مربوط به همین فایل‌های تازه هستند.

اسکریپت بازتولیدپذیری:

```bash
./tools/build_android.sh
```

این اسکریپت خروجی‌ها را می‌سازد، امضا می‌کند و بررسی‌های زیر را اجرا می‌کند:

```bash
zipalign -c -p 4 <apk>
apksigner verify --verbose --print-certs <apk>
aapt2 dump badging <apk>
aapt2 dump permissions <apk>
sha256sum <apk>
```

### فایل‌های نهایی

| فایل | اندازه | SHA-256 |
| --- | ---: | --- |
| `builds/android/roots-of-sacrifice-debug.apk` | ۸۴٬۷۳۶٬۵۱۸ بایت | `9a98c06b8d5a46e69c4778f4cbe83c57ed35658bcd730ceca75f4289c120e256` |
| `builds/android/roots-of-sacrifice-release.apk` | ۷۹٬۵۳۰٬۱۱۰ بایت | `7a8cd05a6726d9288d00968187540cd19b0f8d7de96407cd675c05d27a6f3e25` |

### مشخصات تأییدشده

- نام بسته: `ir.roots_of_sacrifice.game`
- نسخه: `1.0.0`، `versionCode=1`
- `minSdkVersion=24`
- `targetSdkVersion=36`
- `compileSdkVersion=36`
- ABI: `arm64-v8a`، `armeabi-v7a`
- امضای release: RSA 2048، Scheme v2 و v3
- SHA-256 گواهی release: `cc66b06d152fffe334ae588627fcc05ed353256d3b9b7b233fd759026cef0a3c`
- SHA-256 گواهی debug: `09d3503eed310908717972f2ff21fc90fcc20346e0dfb35d60cdd1c2eec97f3c`
- نسخهٔ release دارای پرچم `application-debuggable` نیست.
- خروجی permissions:

```text
package: ir.roots_of_sacrifice.game
```

هیچ مجوز اینترنت یا مجوز حساس دیگری در manifest نهایی دیده نشد.

## مشاهدهٔ دسکتاپ

تصاویر زیر با اجرای واقعی صحنهٔ اصلی Godot تولید شدند؛ منوی اصلی، HUD باغ و پنجرهٔ بستر از نظر چیدمان فارسی و RTL بررسی بصری شد:

- `tools/ignored/runtime-menu.png`
- `tools/ignored/runtime-about.png`
- `tools/ignored/runtime-button-images.png`
- `tools/ignored/runtime-hud-images.png`
- `tools/ignored/runtime-icon-atlas.png`
- `tools/ignored/runtime-garden.png`
- `tools/ignored/runtime-npc.png`
- `tools/ignored/runtime-npc-story.png`
- `tools/ignored/runtime-npc-raha-story.png`
- `tools/ignored/runtime-species.png`
- `tools/ignored/runtime-night.png`
- `tools/ignored/runtime-chapter-01.png`
- `tools/ignored/runtime-chapter-02.png`
- `tools/ignored/runtime-chapter-03.png`
- `tools/ignored/runtime-chapter-04.png`
- `tools/ignored/runtime-chapter-05.png`
- `tools/ignored/runtime-chapter-06.png`
- `tools/ignored/runtime-chapter-07.png`
- `tools/ignored/runtime-chapter-08.png`
- `tools/ignored/runtime-compost.png`
- `tools/ignored/runtime-plot.png`
- `tools/ignored/runtime-memorial-form.png`
- `tools/ignored/runtime-quiz.png`
- `tools/ignored/runtime-ending.png`

این پوشه عمداً در `.gitignore` و exclude filter خروجی قرار دارد.

## موارد باز و محدودیت‌های صادقانه

1. Poco X7 Pro فیزیکی با Android 16 و GPU Mali-G720 آزموده شد؛ اجرای بازی جدید و دوبارهٔ ذخیره بدون کرش و بدون خطای Godot انجام شد. دستگاه فیزیکی Samsung/Huawei، armv7، GPUهای Adreno/PowerVR، چرخش صفحه، Home/خاموشی/ANR و تماس واقعی هنوز آزموده نشده‌اند؛ بنابراین سازگاری «همهٔ گوشی‌ها» ادعا نمی‌شود.
2. تست خودکار روی منطق، APIها و دود UI با صحنهٔ واقعی متمرکز است و جایگزین پیمایش دستی تمام دکمه‌ها، ورودی لمسی و بررسی GPU دستگاه نیست.
3. هشدار ObjectDB اجرای headless با `AudioManager.shutdown()`، غیرفعال‌سازی پخش در درایور headless و انتظار ۰٫۱۵ ثانیه برای آزادسازی thread صدا برطرف شد؛ سه اجرای متوالی و یک اجرای verbose بدون هشدار نشت تمام شدند. روی Poco نیز AudioTrack و موسیقی بدون خطای بارگذاری اجرا شدند؛ شنیداری دستی، تماس و خروج واقعی روی دستگاه هنوز بررسی نشده است.
4. قوانین رسمی مسابقه در دسترس نبوده‌اند؛ این گزارش ادعای انطباق رسمی ندارد.
5. روایت‌های سه NPC دربارهٔ شهیدان واقعی‌اند و هرکدام منبع دارد؛ هشت روایت رها تخیلی و دربارهٔ پدر شهید اوست و با برچسب روشن نمایش داده می‌شود. پیام‌های یادبود بازیکن محلی‌اند و هیچ نام، تاریخ یا نقل‌قول تاریخی بدون منبع به روایت‌ها نسبت داده نمی‌شود.
6. سرویس تولید ویدئوی خارجی با خطای دسترسی/اعتبار پاسخ نداد؛ بنابراین فایل ویدئویی تولید نشد. پس‌زمینهٔ سینمایی به‌صورت shader زمان‌واقعی روی همان تصویر پیاده شده و این گزارش آن را «ویدئو» معرفی نمی‌کند.

جزئیات ماتریس پذیرش در [docs/TESTING.md](TESTING.md) و مراحل بازسازی و نصب در [docs/ANDROID_BUILD.md](ANDROID_BUILD.md) قرار دارد.
