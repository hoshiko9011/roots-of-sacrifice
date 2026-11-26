# ریشه‌های ایثار / Roots of Sacrifice

بازی دوبعدی پیکسل‌آرت، فارسی، راست‌چین و کاملاً آفلاین برای اندروید؛ ساخته‌شده با Godot 4.7.2 توسط گروه **نیوتک / NewTech**.

بازیکن در شهر تخیلی «نوبهار» باغی فراموش‌شده را احیا می‌کند، نهال می‌کارد، آب و خاک را مدیریت می‌کند، با همسایه‌ها همکاری می‌کند، روایت‌های مستند را می‌شنود و پیام‌های یادبود می‌نویسد. بازی هشت فصل، ۳۰ مأموریت، ۱۷ پرسش، شش درخت بومی ایران و ۳۲ روایت NPC دارد.

> **وضعیت انتشار:** نسخهٔ `1.0.0` با `versionCode=1` در Releases منتشر شده است. این README وضعیت پیاده‌سازی و شواهد آزمون را ثبت می‌کند، نه قابلیت‌های آینده را.

## دانلود و اطلاعات نسخه

- [صفحهٔ Release نسخهٔ ۱.۰.۰](https://github.com/hoshiko9011/roots-of-sacrifice/releases/tag/v1.0.0)
- [دانلود مستقیم APK امضاشده](https://github.com/hoshiko9011/roots-of-sacrifice/releases/download/v1.0.0/roots-of-sacrifice-release.apk)
- نام بسته: `ir.roots_of_sacrifice.game`
- نسخه: `1.0.0`، `versionCode=1`
- حجم release: `79,530,110` بایت
- SHA-256 فایل release:

```text
7a8cd05a6726d9288d00968187540cd19b0f8d7de96407cd675c05d27a6f3e25
```

## مشخصات فنی

| مورد | مقدار فعلی |
| --- | --- |
| موتور | Godot `4.7.2.stable.official.ed1daf0bf` |
| زبان اسکریپت | GDScript 4 |
| پلتفرم اصلی | Android، تک‌نفره، آفلاین، افقی |
| رندر | GL Compatibility / GLES3 |
| viewport پایه | `1280×720` |
| کشش نمایش | `canvas_items` با حفظ نسبت تصویر |
| معماری‌های Android | `arm64-v8a` و `armeabi-v7a` |
| حداقل اندروید | API 24 / Android 7.0 |
| اندروید هدف و compile | API 36 |
| امضای APK | APK Signature Scheme v2 و v3 |
| فونت | Vazirmatn Regular و Bold همراه مجوز OFL |
| ذخیرهٔ بازی | محلی در مسیر `user://` |
| شبکه و سرور | ندارد |
| مجوز Android | هیچ مجوزی در manifest نهایی ثبت نشده است |

## قابلیت‌های پیاده‌سازی‌شده

- هشت فصل با پس‌زمینهٔ اختصاصی، دیالوگ آغاز، مأموریت، پاداش و پایان فصل.
- چهار منطقهٔ قابل‌بازدید: باغ، مدرسه، پارک محله و شهر سبز؛ هر منطقه شش بستر کاشت دارد.
- آماده‌سازی خاک، کاشت، آبیاری، کمپوست، سلامت، رطوبت، خاک، نور و رشد روزانهٔ نهال.
- چرخهٔ خودکار روز و شب با مدت قابل‌تنظیم از ۲ تا ۸ دقیقه.
- جمع‌آوری پسماند، بازیافت، کمک به NPC و تنوع زیایی.
- نقشهٔ فصل‌ها و بازدید از مکان‌های بازشده بدون تغییر فصل فعال.
- ۳۲ روایت شخص اول برای چهار NPC در هشت فصل؛ ۲۴ روایت واقعی و مستند و هشت روایت تخیلی رها.
- ثبت نام و پیام یادبود روی نهال‌های کاشته‌شده.
- ۱۷ پرسش، بازخورد آموزشی و ۱۱ دستاورد.
- جوی‌استیک لمسی، دکمه‌های «عمل» و «آب»، تعامل مستقیم و معادل‌های صفحه‌کلید.
- رابط فارسی RTL، ارقام فارسی، HUD تصویری و دکمه‌های سه‌حالته.
- تنظیمات موسیقی، صدا، مدت روز، کنترل لمسی و کاهش حرکت.
- ذخیرهٔ خودکار، ذخیرهٔ دستی، نسخهٔ پشتیبان و Continue از صفحهٔ اصلی.
- آموزش اولیه، آموزش ویژگی‌های تازه و راهنمای ۱۱ مرحله‌ای.
- پس‌زمینهٔ سینمایی زمان‌واقعی با shader اختصاصی در منوی اصلی و ending.
- ۱۵ افکت صوتی WAV تولیدی و چهار آهنگ MP3 ارائه‌شده توسط صاحب پروژه.

## وضعیت تست گوشی‌ها و دستگاه‌ها

این جدول فقط شاهد اجراشده را نشان می‌دهد. وجود پشتیبانی فنی یا بسته‌بندی یک معماری به معنای تست فیزیکی آن دستگاه نیست.

| دستگاه یا خانواده | وضعیت | شاهد و محدوده |
| --- | --- | --- |
| **POCO X7 Pro / Xiaomi-POCO** | **تست فیزیکی شده** | مدل `2412DPC0AG`، Android 16، GPU Mali-G720، معماری arm64؛ نصب با `adb install -r`، اجرای بازی جدید، اجرای دوبارهٔ ذخیره، نبود کرش و خطای Godot، راه‌اندازی AudioTrack |
| سایر گوشی‌های Xiaomi | تست فیزیکی نشده | فقط خانوادهٔ Xiaomi/POCO و مدل فوق شاهد فیزیکی دارند |
| سایر گوشی‌های POCO | تست فیزیکی نشده | فقط Poco X7 Pro شاهد فیزیکی دارد |
| Samsung | تست فیزیکی نشده | emulator موجود در محیط پایدار نبود و پاسخ adb نداد؛ به‌عنوان شاهد قبول نشد |
| Huawei | تست فیزیکی نشده | هیچ شاهد فیزیکی موجود نیست |
| برندهای دیگر | تست فیزیکی نشده | شامل Realme، Oppo، Vivo، Honor، Nokia و سایر برندها |
| armv7 / `armeabi-v7a` | بسته‌بندی شده، تست فیزیکی نشده | کتابخانهٔ ARMv7 در APK وجود دارد اما روی دستگاه armv7 اجرا نشده است |
| GPU Adreno و PowerVR | تست فیزیکی نشده | فقط Mali-G720 روی Poco X7 Pro شاهد فیزیکی دارد |
| Windows Desktop | تست خودکار و رندر تصویری شده | اجرای headless، ۳۲۵ بررسی و رندر صحنه‌ها؛ بازی‌کردن دستی کامل دسکتاپ انجام نشده است |

### آزمون‌های فیزیکی انجام‌شده روی Poco X7 Pro

- نصب نسخهٔ release با حفظ نسخهٔ قبلی از طریق `adb install -r`.
- اجرای بازی جدید تا ورود به gameplay.
- بستن و اجرای دوبارهٔ بازی با ذخیرهٔ موجود.
- بررسی لاگ دستگاه برای کرش و خطاهای Godot.
- تأیید راه‌اندازی مسیر صوتی Android با `AudioTrack`.
- رفع کرش قبلی ناشی از انتخاب MP3 ناموجود به‌جای WAV imported با `ResourceLoader.exists()` و جلوگیری از ارسال stream خالی به پخش‌کننده.

### مواردی که هنوز روی دستگاه تأیید نشده‌اند

- پیمایش دستی تمام دکمه‌ها و صفحه‌ها روی Android.
- لمس فیزیکی همهٔ کنترل‌ها، Android Back، چرخش صفحه و رفتار notch/gesture navigation.
- تماس واقعی، Home، خاموش‌کردن صفحه، ANR و چرخهٔ کامل focus صوتی.
- مسیر طبیعی پایان هشت فصل و تمام ۳۰ مأموریت با ورودی لمسی دستگاه.
- اندازه‌گیری FPS، مصرف حافظه، دما و عملکرد طولانی‌مدت.
- سازگاری Samsung، Huawei، armv7، Adreno، PowerVR و سایر برندها.

به همین دلیل، سازگاری «همهٔ گوشی‌ها» ادعا نمی‌شود.

## معماری پروژه

صحنهٔ اصلی `scenes/main.tscn` است و دو autoload اصلی پروژه عبارت‌اند از:

- `GameState`: منطق پیشرفت، زمان، مأموریت، منابع، رشد، ذخیره و تنظیمات.
- `AudioManager`: موسیقی، ambience، افکت‌های صوتی، حجم‌ها و توقف صدا.

جریان اصلی تعامل:

```text
WorldController.interaction(kind, index)
  → main.gd
  → API مربوطه در GameState
  → سیگنال changed / notification
  → به‌روزرسانی جهان و HUD
```

منطق مأموریت فقط در `GameState` قرار دارد و `WorldController` فایل ذخیره نمی‌نویسد.

### مسئولیت فایل‌های اصلی

| فایل | مسئولیت |
| --- | --- |
| `scripts/main.gd` | منوی اصلی، HUD، مودال‌ها، آموزش، نقشه، تنظیمات، توقف، پرسش، یادبود و ending |
| `scripts/game_state.gd` | state بازی، پیشرفت مأموریت، امتیاز، منابع، رشد روزانه، قفل منطقه، ذخیره و تنظیمات |
| `scripts/data/game_content.gd` | دادهٔ ثابت فصل‌ها، مأموریت‌ها، پرسش‌ها، گونه‌ها، روایت‌ها و دستاوردها |
| `scripts/world.gd` | ساخت جهان، پس‌زمینه‌ها، NPCها، بسترها، پسماند، آب‌پاش، برخورد و تعامل |
| `scripts/player.gd` | حرکت `CharacterBody2D`، برخورد هندسی و انیمیشن بازیکن |
| `scripts/plot.gd` | رسم و وضعیت بصری هر بستر و نهال |
| `scripts/touch_joystick.gd` | ورودی لمس جوی‌استیک و reset هنگام pause/focus loss |
| `scripts/ui_factory.gd` | کنترل‌های فارسی/RTL، فونت، دکمه، پنل، تصویر و نوار پیشرفت |
| `scripts/atlas.gd` | cache دارایی، `AtlasTexture` و نگاشت گیاه/آیکون |
| `scripts/audio_manager.gd` | cache صدا، crossfade موسیقی، ambience، SFX و وضعیت pause |
| `assets/art/cinematic_garden.gdshader` | حرکت برگ، شال، ابر، فواره، موج و زوم آرام تصویر سینمایی |
| `tests/run_tests.gd` | تست منطق، محتوا، دارایی، ذخیره و UI smoke |
| `tools/build_android.sh` | import، export، align، امضا و بررسی APK |

## سیستم‌های بازی

### فصل‌ها و مأموریت‌ها

هشت فصل و ۳۰ مأموریت در `GameContent` تعریف شده‌اند. شناسهٔ مأموریت بین فصل‌ها تکرار می‌شود، اما `register_event()` با کلید `chapter:id:unique_key` تکرار را کنترل می‌کند و فقط مأموریت‌های فصل فعال را پیش می‌برد.

پایان فصل تنها پس از تکمیل مأموریت‌های فصل فعال فعال می‌شود. امتیاز اختیاری شرط عبور به فصل بعد نیست. بستن پنجرهٔ پایان فصل، مأموریت را برای ادامه نگه می‌دارد.

### کاشت و رشد

هر بستر یک نهال دارد و وضعیت آن شامل این فیلدهاست:

```text
prepared, species, stage, moisture, soil, health, growth,
watered_day, planted_day, compost_day, sun, name, dead, neglect_days
```

قواعد اصلی:

- آماده‌سازی خاک، `soil` را افزایش می‌دهد و یک اقدام اکویی ثبت می‌کند.
- کاشت یک seed مصرف می‌کند و نهال را در مرحلهٔ اول قرار می‌دهد.
- آبیاری در صورت نیاز، رطوبت و سلامت را افزایش می‌دهد.
- کمپوست خاک و سلامت را بهبود می‌دهد و مصرف آن روزانه محدود است.
- رشد روزانه به رطوبت، خاک، نور و نیازهای گونه وابسته است.
- نور کافی ضریب رشد `1.0` و نور ناکافی ضریب `0.7` دارد.
- سلامت در شرایط مناسب افزایش و در شرایط نامساعد کاهش می‌یابد.
- نهال بی‌مراقبت می‌تواند بمیرد و بستر برای کاشت دوباره آزاد شود.

مقادیر نیاز آب، نور و رشد برای گونه‌ها **مقادیر تعادلی تخیلی بازی‌اند** و توصیهٔ کشاورزی واقعی محسوب نمی‌شوند.

### زمان و هوا

- دورهٔ پیش‌فرض روز: `240` ثانیه.
- بازهٔ قابل‌تنظیم: `120` تا `480` ثانیه.
- هوا بر اساس `day % 4` انتخاب می‌شود: آفتابی، نیمه‌ابری یا بارانی.
- رشد به زمان واقعی یا اینترنت وابسته نیست.
- توقف بازی و آموزش، ساعت بازی را متوقف می‌کنند.
- شب، نور محیط و انتخاب موسیقی را تغییر می‌دهد.

### روایت‌ها و محتوای تاریخی

- چهار NPC در هشت فصل روایت متفاوت دارند.
- ۲۴ روایت سه NPC دربارهٔ شهیدان واقعی‌اند و نام، روایت‌گوی اصلی، عنوان منبع و آدرس منبع در داده و UI موجود است.
- هشت روایت رها دربارهٔ پدر شهید او تخیلی‌اند و با برچسب «روایت تخیلی» از محتوای تاریخی جدا می‌شوند.
- هیچ نام، تاریخ، خاطره یا نقل‌قول تاریخی بدون منبع تولید نشده است.
- آدرس‌های منبع در `game_content.gd` فقط ارجاع متنی‌اند؛ بازی آن‌ها را باز نمی‌کند یا در runtime دریافت نمی‌کند.
- روایت‌ها متن‌اند و صدای گفتاری تولید نمی‌کنند.

### کنترل‌ها

| عمل | لمسی | صفحه‌کلید |
| --- | --- | --- |
| حرکت | جوی‌استیک پایین چپ | `WASD` یا کلیدهای جهت‌دار |
| تعامل و گفت‌وگو | لمس مستقیم هدف یا دکمهٔ «عمل» | `E` یا `Space` |
| آبیاری | دکمهٔ «آب» یا دکمهٔ آب کنار نهال | `Q` |
| توقف | دکمهٔ «توقف» | `Escape` |
| بازگشت Android | دکمهٔ Back سیستم | مدیریت مودال، توقف یا تأیید خروج |

جوی‌استیک `150×150` است و دکمه‌های لمسی «عمل» و «آب» هر کدام `120×88` هستند. کارت آموزش در بالای کنترل‌ها قرار می‌گیرد و با دکمه‌های لمسی هم‌پوشانی ندارد.

## رابط، صدا و cinematography

- تمام متن‌های کاربردی فارسی و RTL هستند.
- مقدار و نام منابع HUD برای خوانایی وسط‌چین‌اند.
- آدرس لاتین منبع به‌عنوان استثنای LTR و چپ‌چین باقی می‌ماند.
- دکمه‌های منو، HUD، مودال و کنترل لمسی از خانوادهٔ بصری مشترک چوب/برگ استفاده می‌کنند.
- دکمه‌های اصلی سه تصویر مستقل `normal/hover/pressed` دارند.
- `AudioManager` دو پخش‌کنندهٔ موسیقی با crossfade، دو ambience و شش SFX round-robin دارد.
- توقف بازی، موسیقی و ambience را pause و SFXها را stop می‌کند.
- Settings بازشده از Pause، ساعت را متوقف نگه می‌دارد اما صدا را برای پیش‌نمایش دوباره فعال می‌کند.
- `reduced_motion` حرکت اتمسفر و shader سینمایی را کاهش یا متوقف می‌کند.
- پس‌زمینهٔ سینمایی یک تصویر ثابت با shader زمان‌واقعی است، نه فایل ویدئوی فشرده.

## ذخیره و بازیابی

مسیرهای محلی:

```text
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

## تیم

**نیوتک / NewTech**

- یاسمین رضایی
- یاسمن بخشی‌زاده

شعار پروژه:

> هر نهال، فرصتی برای ساختن آینده‌ای سبزتر است.
