# گزارش بازرسی فنی و کیفیت Roots of Sacrifice

- تاریخ: ۲۰۲۶-۱۱-۲۷
- شاخه: `audit/android-stability-qa`
- مبنای مقایسه: `e46ce0596961a9f5046ca76865f4328c95dfb91d` روی `main`
- موتور: Godot `4.7.2.stable.official.ed1daf0bf`
- دامنه: لمس، چرخهٔ حیات Android، کارایی، صدا، ذخیره و پیشرفت، گیم‌پلی، رابط فارسی/RTL، گرافیک، تست خودکار و بستهٔ Android

## نتیجهٔ اجرایی

بازرسی روی شاخهٔ جدا انجام شد و هیچ داستان، شخصیت، مأموریت، دارایی هنری، موسیقی یا مکانیک پایهٔ بازی تغییر نکرد. برای هر نقص تأییدشده، اصلاح هدفمند و تست رگرسیون اضافه شد.

نتیجهٔ نهایی تست خودکار:

```text
ROOTS_TESTS: 359 checks, 0 failures
```

۳۵۹ بررسی در برابر ۳۲۵ بررسی نسخهٔ پایه اجرا شد. اسکریپت ساخت Android نیز پیش از export، همین مجموعه را اجرا می‌کند و در صورت خطا، ساخت APK را متوقف می‌کند.

## نقص‌های تأییدشده و اصلاحات

| # | مشکل و علت | فایل / تابع | اصلاح و تست |
|---:|---|---|---|
| 1 | مختصات لمس جوی‌استیک با فضای canvas یکی نبود؛ در مقیاس‌های غیر ۱۲۸۰×۷۲۰ لمس اشتباه خوانده می‌شد. | `scripts/touch_joystick.gd` / `_input`, `_update_direction` | تبدیل ورودی با `make_input_local(event).position` و محاسبهٔ مرکز از `size`؛ تست در viewport ۱۹۲۰×۱۰۸۰. |
| 2 | لغو لمس Android با `index=-1` می‌توانست انگشت و حرکت جوی‌استیک را قفل نگه دارد. | `scripts/touch_joystick.gd` / `_input`, `reset` | رسیدگی صریح به `canceled` و `index=-1`؛ تست لغو و لمس مجدد پس از لغو. |
| 3 | دکمه‌های معمولی Godot هم‌زمانی حرکت و Action/Water را با چند انگشت تضمین نمی‌کردند. | `scripts/touch_action_button.gd`، `scripts/ui_factory.gd`، `scripts/main.gd`، `scripts/world.gd` | کلاس `TouchActionButton` با ثبت مستقل انگشت، انتظار و لغو؛ جایگزینی فقط کنترل‌های گیم‌پلی با حفظ ظاهر دکمه‌ها. تست هم‌زمانی جوی‌استیک + Action و جوی‌استیک + Water. |
| 4 | لایهٔ منو در حال محو شدن، ورودی را پیش از پایان انیمیشن می‌گرفت. | `scripts/main.gd` / `_close_modal`, `_set_input_transparent` | شفاف‌سازی ورودی همهٔ کنترل‌های لایهٔ در حال بسته‌شدن؛ تست بررسی فوری پس از `_close_modal`. |
| 5 | بستن deferred منو پس از از دست رفتن فوکوس، صدای متوقف‌شده را دوباره پخش می‌کرد. | `scripts/main.gd` / `_close_modal`, `_notification` | بازیابی صدا با درنظرگرفتن `_audio_paused_by_focus`؛ تست فوکوس lost/gained. |
| 6 | Back هنگام آموزش، زیرمنوی آموزش یا خود آموزش را نمی‌بست. | `scripts/main.gd` / `_handle_back_action` | ترتیب صحیح: بستن زیرمنو، سپس نمایش تأیید خروج و حفظ آموزش فعال. |
| 7 | رفتن برنامه به پس‌زمینه، منوی فعال یا آموزش را با صفحهٔ توقف جایگزین می‌کرد. | `scripts/main.gd` / `_notification` | فقط در نبود منو و آموزش، صفحهٔ توقف ساخته می‌شود. |
| 8 | ساعت، مراقبت گیاهان و موسیقی در صفحهٔ عنوان و پایان ادامه داشتند. | `scripts/main.gd` / `_clear_screen`, `_process` | `GameState.time_paused` بیرون از گیم‌پلی؛ تست ثابت‌ماندن روز و ساعت. |
| 9 | هر تغییر HUD، تمام chipها و labelها را از نو می‌ساخت. | `scripts/main.gd` / `_refresh_hud`, `_hud_chip` | cache کردن chip و value label؛ تست ۱۰۰ refresh با حفظ هر هشت instance. |
| 10 | رفتن به نقشه/گیاه/فصل، world و screen gameplay را دوباره می‌ساخت. | `scripts/main.gd` / `_visit_zone`, `_resume_live_world`, مسیرهای chapter/map/plant | استفادهٔ مجدد از world فعال و refresh درجا؛ تست حفظ instance screen/world. |
| 11 | نوشتن دیسک هر ده ثانیه حتی با تغییر نکردن دادهٔ گیم‌پلی انجام می‌شد. | `scripts/game_state.gd` / `_process`, `_autosave` | تفکیک dirty گیم‌پلی از dirty ساعت و autosave ساعت فقط هر ۶۰ ثانیه. |
| 12 | خطای نوشتن/flush ذخیره بررسی نمی‌شد و می‌توانست فایل معتبر یا backup قبلی را endanger کند. | `scripts/game_state.gd` / `save_game` | بررسی `get_error()` بعد از نوشتن و flush، حذف temp ناقص، حفظ dirty و بازگرداندن false. |
| 13 | خطای autosave بی‌صدا بود. | `scripts/game_state.gd` / `_fail_save` | اعلان خطا با throttle ۳۰ ثانیه؛ تست حفظ فایل اصلی و dirty. |
| 14 | جایگزینی backup اتمی نبود. | `scripts/game_state.gd` / `save_game` | کپی به `backup_path + ".tmp"`، اعتبارسنجی envelope و rename اتمی؛ حذف temp در شکست. |
| 15 | شروع batch کمپوست در ظرفیت پر، مواد اولیه مصرف می‌شد و خروجی از دست می‌رفت. | `scripts/game_state.gd` / `start_compost_batch`، `scripts/main.gd` / `_compost` | رد شروع بالاتر از چهار واحد و غیرفعال‌کردن دکمه؛ تست بدون مصرف مواد. |
| 16 | آموزش کمپوست فقط با باز شدن پنل کامل می‌شد، نه با ساخت واقعی. | `scripts/main.gd` / `_interaction`, `_compost`, `_process` | حذف تکمیل زودهنگام و تکمیل بر اساس افزایش `stats.compost_built`؛ تست گیتینگ با مرحلهٔ سفارشی. |
| 17 | لمس مستقیم NPC یا کمپوست از فاصلهٔ دور، محدودیت تعامل را دور می‌زد. | `scripts/world.gd` / `_click_target` | اعمال `INTERACTION_DISTANCE` برای هر دو مسیر؛ تست عدم باز شدن منو از فاصلهٔ دور. |
| 18 | نام «سرو امید» پس از پاک‌کردن نهال مرده از plaque یادبود حذف می‌شد. | `scripts/game_state.gd` / `clear_dead_plot` | حفظ `plot.name` برای بستر یادبود؛ تست plaque و نام مرئی. |
| 19 | migration نسخهٔ ۲ روی فایل بدون `species` می‌توانست خطا بدهد. | `scripts/game_state.gd` / migration v2 | تبدیل امن مقادیر اختیاری با `String(...)`؛ تست دادهٔ ناقص سازگار. |
| 20 | با تغییر موقعیت، همان stream باد با gain مکان قبلی ادامه می‌داد. | `scripts/audio_manager.gd` / `set_zone`, `_start_ambience` | به‌روزرسانی ambience scale و volume در early return همان stream. |
| 21 | صف toast محدود نبود و پیام‌های تکراری پشت‌سر هم نمایش داده می‌شدند. | `scripts/main.gd` / `_toast` | حذف تکرار پیام جاری/متوالی و سقف ۱۲ پیام؛ تست ۱۰۰ پیام. |
| 22 | دکمهٔ آب contextual می‌توانست روی آموزش رسم شود. | `scripts/main.gd` / `_show_game` | `overlay.z_index = 100`؛ تست Z نسبت به دکمهٔ آب. |
| 23 | درختان چراغ‌دار در پارک بدون prop چراغ، glow شبانه داشتند. | `scripts/world.gd` / `_draw` | محدودکردن glow شبانه به شهر؛ تست مکان شهر. |
| 24 | ساخت APK حتی با شکست تست‌ها ادامه پیدا می‌کرد. | `tools/build_android.sh` | اجرای اجباری تست رگرسیون پیش از export؛ تست بررسی ترتیب اسکریپت. |
| 25 | بیرون کشیدن انگشت از Action/Water یا رهاکردن mouse خارج از دکمه، بازهم action را اجرا می‌کرد. | `scripts/touch_action_button.gd` / `_gui_input` | لغو ورودی با `_cancel_input()` هنگام خروج از rect و اجرای `pressed` فقط در صورت release داخل دکمه؛ تست مستقل لمس و mouse برای هر دو دکمه. |

## تست‌های رگرسیون افزوده‌شده

- تبدیل مختصات جوی‌استیک در مقیاس ۱۹۲۰×۱۰۸۰.
- لمس، drag، لغو Android و لمس جدید پس از لغو.
- Action و Water مستقل و هم‌زمان با نگه‌داشتن حرکت.
- شفاف‌سازی ورودی منوی در حال بسته‌شدن.
- Back در آموزش و زیرمنوی آموزش.
- حفظ حالت pause صدا پس از focus loss و بستن deferred.
- حفظ منوی فعال هنگام pause برنامه.
- ثابت‌ماندن ساعت و مراقبت در عنوان و پایان.
- استفادهٔ مجدد chipها پس از ۱۰۰ refresh.
- استفادهٔ مجدد screen و world هنگام سفر.
- سقف و deduplication اعلان‌ها.
- تکمیل آموزش کمپوست فقط پس از ساخت واقعی.
- Z-order آموزش و دکمهٔ آب.
- محدودیت فاصله برای لمس مستقیم NPC و کمپوست.
- clock-only autosave در ۶۰ ثانیه و نبود autosave ده‌ثانیه‌ای بی‌دلیل.
- شکست نوشتن، شکست backup، نبود temp ناقص و اعلان throttle.
- ظرفیت کمپوست و migration نسخهٔ ۲.
- gain ambience هنگام استفادهٔ مجدد stream.
- اجرای تست پیش از export و glow مخصوص شهر.

## کارایی پیش و پس از اصلاح

اندازه‌گیری با `tools/ignored/perf_probe.gd` روی همان صحنه و شاخهٔ مبنا انجام شد. اعداد حافظه بایت‌اند. این اعداد یک‌بار اجرا و محیط دسکتاپ‌اند، نه شاهد FPS گوشی.

| سنجه | پیش از | پس از | تغییر |
|---|---:|---:|---:|
| Headless FPS | ۶۷ | ۹۷ | +۴۴٫۸٪ |
| Headless: زمان ۱۰۰ refresh HUD | ۱٬۵۳۱٬۷۵۳ µs | ۷٬۳۸۶ µs | حدود ۲۰۷× سریع‌تر |
| Headless: ساخت world | ۲۵۱٬۶۸۹ µs | ۱۱۲٬۱۲۰ µs | حدود ۵۵٪ کمتر |
| Headless: MEMORY_STATIC | ۷۸٬۴۷۶٬۹۹۴ | ۷۵٬۸۴۴٬۴۰۷ | حدود ۳٫۴٪ کمتر |
| Desktop render FPS | ۶۰ | ۶۰ | سقف VSync |
| Desktop: زمان ۱۰۰ refresh HUD | ۱٬۱۴۷٬۹۰۰ µs | ۷٬۸۸۲ µs | حدود ۱۴۶× سریع‌تر |
| Desktop: ساخت world | ۲۳۰٬۳۸۸ µs | ۱۸۱٬۱۲۷ µs | حدود ۲۱٪ کمتر |
| Desktop: MEMORY_STATIC | ۵۳٬۳۸۳٬۳۷۶ | ۴۹٬۶۶۰٬۶۸۱ | حدود ۷٪ کمتر |
| Desktop: MEMORY_STATIC_MAX | ۵۶٬۵۵۲٬۱۱۴ | ۵۶٬۰۰۷٬۲۳۱ | حدود ۱٪ کمتر |
| تعداد chip پس از ۱۰۰ refresh | بازسازی می‌شد | هر ۸ instance حفظ شد | تخصیص حذف شد |
| تعداد node صحنه | ۱۱۵ | ۱۱۵ | بدون تغییر ساختار بصری |

FPS حالت headless معیار سریع‌تر اجرای حلقهٔ engine است و نباید به‌عنوان نرخ فریم سخت‌افزاری گزارش شود. در اجرای رندر، ۶۰ FPS به سقف VSync محدود است.

## Android، امنیت و حریم خصوصی

- Godot، GL Compatibility و قالب landscape حفظ شده‌اند.
- APK شامل ARM64 و ARMv7 است.
- اسکریپت ساخت، import، تست، export، themed icon، `zipalign`، امضا و بررسی `apksigner` را اجرا می‌کند.
- هیچ مجوز Android، شبکه، ردیابی، تبلیغات، خرید درون‌برنامه‌ای یا قابلیت آنلاین اضافه نشد.
- کلیدها و رمزها فقط از مسیر محلی `builds/keystore` خوانده می‌شوند و در گزارش، Git یا لاگ چاپ نمی‌شوند.
- چهار موسیقی کاربر همچنان دارایی مجاز و تحویل‌شده توسط صاحب پروژه‌اند.
- تاریخ و روایت‌های شهدا بدون تغییر محتوایی باقی ماندند؛ رهای تخیلی همچنان برچسب تخیلی دارد.

ساخت نهایی ۲۰۲۶-۱۱-۲۷ با `tools/build_android.sh` موفق بود. هر دو APK با Scheme v2 و v3 امضا و با `zipalign -c -p 4` بررسی شدند.

| فایل | اندازه | SHA-256 |
|---|---:|---|
| `builds/android/roots-of-sacrifice-debug.apk` | ۸۴٬۷۴۰٬۷۸۷ بایت | `7baded8d5b7775915b73cc03d7d15c31a89ee388508bd6c4a9faac0f3f52c62f` |
| `builds/android/roots-of-sacrifice-release.apk` | ۷۹٬۵۳۸٬۴۷۵ بایت | `8636361cd38bc320f01c5c5ba4a9bd01eb89bb5af8bcbf5fe2a17b700044ab4b` |

### تست فیزیکی تکمیلی روی Poco X7 Pro

در ۲۰۲۶-۱۱-۲۷ APK نسخهٔ نهاییِ همین شاخه با `adb install -r` روی گوشی `2412DPC0AG` با Android 16 نصب شد؛ دادهٔ کاربر پاک نشد و نصب incremental موفق بود. بازی اجرا شد، صفحهٔ گیم‌پلی و آموزش دیده شد، رفتن به Home و بازگشت باعث `OnPause`/`OnStop` سپس `OnStart`/`OnResume` شد و صفحهٔ توقف بدون کرش نمایش داده شد. process پس از بازگشت زنده ماند و `logcat -b crash` یا خطای Godot/ANR ثبت نشد.

نمونهٔ حافظه پس از بازگشت: `TOTAL PSS = 356668 kB`، `TOTAL RSS = 505136 kB`، Graphics = `165352 kB`.

تزریق لمس با `adb shell input tap` روی این دستگاه با `SecurityException: INJECT_EVENTS` مسدود شد؛ بنابراین تست خودکار دکمه‌ها و چندلمسی روی گوشی انجام نشد و تنظیم امنیتی گوشی تغییر داده نشد.

## محدودیت‌ها و موارد باز

1. تست فیزیکی محدود به Poco X7 Pro / Android 16 / Mali-G720 انجام شده است؛ این نتیجه به‌طور خودکار به سایر گوشی‌ها تعمیم داده نمی‌شود.
2. نصب incremental، اجرا و چرخهٔ Home/resume نسخهٔ بازبینی‌شده روی همین گوشی موفق بود، اما تعامل لمسی خودکار به‌دلیل سیاست امنیتی MIUI مسدود ماند.
3. armv7 فیزیکی، Samsung، Huawei، Adreno و PowerVR تست فیزیکی نشده‌اند.
4. تست دستی Home، خاموشی صفحه، تماس واقعی، audio focus واقعی، Back فیزیکی، soak طولانی و فصل کامل روی گوشی همچنان لازم است.
5. cold start در airplane mode، نصب تازه، ارتقای چندنسخه‌ای و حفظ save/settings روی نسخهٔ تازه دستی آزموده نشده‌اند.
6. معیار FPS و حافظهٔ Android ثبت نشده است؛ اعداد گزارش فقط دسکتاپ/headless هستند.
7. خطای engine در اجرای تست دربارهٔ `roots-audit-missing-dir/backup.json.tmp` عمدی و بخشی از تست شکست backup است؛ failure مستقل ایجاد نمی‌کند.
8. تغییرات روی شاخهٔ بازبینی آمده‌اند و تا درخواست صریح، به `main` merge یا جایگزینی Release v1.0.0 نمی‌شوند.

## اجرای تست و ساخت

از ریشهٔ پروژه:

```bash
./tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --scene res://tests/test_runner.tscn
bash tools/build_android.sh
```

`tools/build_android.sh` خودش import و اجرای کامل تست‌ها را انجام می‌دهد و APKهای debug/release امضاشده را در `builds/android` می‌سازد.

نصب نسخهٔ release روی دستگاه متصل:

```bash
C:/Users/Yasamin/.evolab-toolchain/sdk/platform-tools/adb.exe install -r builds/android/roots-of-sacrifice-release.apk
```

پس از ساخت نهایی، اندازه و SHA-256 دقیق APKها در `docs/ANDROID_BUILD.md`، `docs/TEST_REPORT.md` و `docs/TESTING.md` ثبت می‌شود.
