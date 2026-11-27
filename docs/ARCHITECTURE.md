# معماری: ریشه‌های ایثار

این سند معماری پیاده‌سازی‌شده را از روی کد و تنظیمات فعلی پروژه توضیح می‌دهد، نه طرح آینده را.

## چارچوب اجرا

- موتور: Godot 4.7.2 (GDScript)، رندر GL Compatibility
- بازی تک‌نفره، دوبعدی، آفلاین و اندرویدمحور، جهت افقی
- viewport پایه: ۱۲۸۰×۷۲۰ با کشش `canvas_items` و حفظ نسبت تصویر
- صحنهٔ اصلی و تنها صحنهٔ بازی: `res://scenes/main.tscn` (اسکریپت `scripts/main.gd`)
- autoloadها: `GameState` و `AudioManager`
- فونت Vazirmatn و `locale/fallback="fa"`
- شبکه، حساب، تبلیغات یا دانلود در زمان اجرا وجود ندارد

```text
scenes/main.tscn
scripts/
  main.gd
  game_state.gd
  audio_manager.gd
  data/game_content.gd
  world.gd
  player.gd
  plot.gd
  touch_joystick.gd
  touch_action_button.gd
  ui_factory.gd
  atlas.gd
tests/
  run_tests.gd
  test_runner.tscn
assets/art, assets/audio, assets/fonts
tools/build_android.sh
project.godot
export_presets.cfg
```

`world.gd` و `plot.gd` در زمان اجرا ساخته می‌شوند و فایل `world.tscn` یا `plot.tscn` وجود ندارد. `main.gd` کلاس نام‌گذاری‌شده ندارد و مستقیماً به صحنهٔ اصلی وصل است.

## مسئولیت ماژول‌ها

| مسیر | کلاس | مسئولیت |
| --- | --- | --- |
| `scripts/data/game_content.gd` | `GameContent` | دادهٔ ثابت فصل‌ها، مأموریت‌ها، پرسش‌ها، گونه‌ها، روایت‌ها و دستاوردها |
| `scripts/game_state.gd` | autoload `GameState` | وضعیت بازی، پیشرفت، زمان، قفل منطقه، ذخیره و تنظیمات |
| `scripts/audio_manager.gd` | autoload `AudioManager` | موسیقی، ambience و افکت‌های صوتی |
| `scripts/world.gd` | `WorldController` | ساخت جهان، انتخاب هدف و ارسال تعامل |
| `scripts/player.gd` | `PlayerController` | حرکت و برخورد `CharacterBody2D` |
| `scripts/plot.gd` | `GardenPlot` | نمایش بستر و نهال |
| `scripts/touch_joystick.gd` | — | ورودی لمس جوی‌استیک (بدون `class_name`) |
| `scripts/touch_action_button.gd` | `TouchActionButton` | چندلمسی مستقل Action/Water و لغو امن هنگام خروج از دکمه |
| `scripts/ui_factory.gd` | `UIFactory` | کنترل‌های فارسی/RTL، دکمه، پنل و فونت |
| `scripts/atlas.gd` | `GameAtlas` | cache دارایی و `AtlasTexture` |
| `scripts/main.gd` | — | منو، HUD، مودال‌ها، تنظیمات، پرسش، یادبود و ending |

جریان تعامل:

```text
WorldController.interaction(kind, index)
  → main.gd
  → API مربوطه در GameState
  → GameState.changed / notification
  → به‌روزرسانی جهان و HUD
```

منطق مأموریت فقط در `GameState` است. `WorldController` فایل ذخیره نمی‌نویسد.

## سیگنال‌ها و APIهای عمومی

```gdscript
# GameState
signal changed
signal notification(message: String)
signal chapter_finished(chapter_id: int)
signal achievement_unlocked(id: String)
signal time_changed
signal day_started(day: int)

# WorldController
signal interaction(kind: String, index: int)
signal hint_changed(text: String)

# touch_joystick.gd
signal direction_changed(direction: Vector2)
```

سیگنال جداگانه‌ای برای ذخیره یا تکمیل هر مأموریت وجود ندارد؛ این رویدادها معمولاً از طریق `changed` و `notification` دیده می‌شوند.

APIهای اصلی `GameState`:

- چرخهٔ بازی: `new_game()`، `current_chapter()`، `chapter_ready()`، `complete_chapter()`، `next_chapter()`
- مأموریت: `task_count(id)`، `register_event(id, unique_key)`
- منطقه: `zone_unlocked(zone)`، `set_zone(zone)`، `plots(zone)`
- بستر و نهال: `prepare_plot(index)`، `plant_tree(index, species)`، `water_plot(index)`، `apply_compost(index)`، `clear_dead_plot(index)`، `refill_water()`
- کمپوست: `build_compost_station()`، `start_compost_batch()`، `collect_compost()`
- پسماند و NPC: `collect_trash(index)`، `talk_npc(index)`، `help_npc(index)`، `read_story(index)`، `read_npc_story(npc_index, chapter)`
- یادبود و پرسش: `has_memorial(...)`، `save_memorial(...)`، `quiz_indices()`، `answer_question(index, option)`
- زمان و ذخیره: `weather()`، `advance_day()`، `has_valid_save()`، `save_game()`، `load_game()`
- تنظیمات: `set_setting(key, value)`، `reset_settings()`، `save_settings()`، `load_settings()`

API عمومی برای ویرایش یا حذف یادبود، انتخاب فصل فعال، یا تاریخچهٔ تلاش پرسش وجود ندارد.

## محتوا و پیشرفت

دادهٔ ثابت در `GameContent` است. شناسهٔ مأموریت بین فصل‌ها تکرار می‌شود؛ `register_event()` با کلید `chapter:id:unique_key` تکرار را رد می‌کند و فقط مأموریت فصل فعال را جلو می‌برد. پایان فصل تنها به تکمیل مأموریت‌های همان فصل وابسته است، نه به سقف امتیاز یا پاسخ همهٔ پرسش‌ها.

| فصل | مکان | مأموریت‌ها | پاداش eco/social/culture/stars |
| ---: | --- | --- | ---: |
| ۱ باغ فراموش‌شده | `garden` | `clean_trash×5`، `talk_guide×1`، `prepare_soil×2` | ۸/۳/۳/۳ |
| ۲ نخستین نهال | `garden` | `plant_tree×2`، `water_tree×3`، `collect_recycle×2` | ۱۰/۲/۳/۳ |
| ۳ راز خاک و آب | `garden` | `prepare_soil×3`، `water_tree×3`، `answer_quiz×2`، `collect_recycle×2` | ۱۲/۲/۴/۴ |
| ۴ مدرسه سبز | `school` | `talk_guide×1`، `plant_school×3`، `collect_recycle×3`، `answer_quiz×2` | ۱۰/۵/۳/۴ |
| ۵ باغ یادبود | `garden` | `read_story×3`، `write_memorial×1`، `add_memorial×1`، `answer_quiz×2` | ۶/۸/۱۰/۴ |
| ۶ همراهی مردم | `park` | `help_people×3`، `collect_recycle×3`، `talk_guide×2`، `read_story×2` | ۸/۱۰/۶/۴ |
| ۷ شهر سبز | `city` | `plant_native×3`، `water_tree×3`، `collect_recycle×4`، `answer_quiz×2` | ۱۲/۶/۵/۵ |
| ۸ ریشه‌های ماندگار | `city` | `mature_tree×2`، `help_people×3`، `final_quiz×3`، `celebrate_city×1` | ۱۵/۱۲/۱۰/۵ |

۱۷ پرسش در محتوا هست (دو پرسش در فصل‌های ۱ تا ۷ و سه پرسش در فصل ۸). پاسخ نادرست پیشرفت یا امتیاز نمی‌دهد؛ نخستین پاسخ درست ثبت می‌شود و تکرار آن پاداش تازه ندارد. `next_chapter()` فهرست `quiz_solved` را پاک می‌کند.

شش گونه: `cypress`، `native_oak`، `pomegranate`، `arghavan`، `olive`، `willow`. ۳۲ روایت برای چهار NPC؛ ۲۴ روایت مستند و هشت روایت تخیلی (NPC رها) با برچسب مشخص. یازده دستاورد از جمله `story_keeper` و `martyr_voices`. مقادیر نیاز آب، نور و رشد گونه‌ها برای تعادل بازی‌اند، نه توصیهٔ کشاورزی.

## مناطق و وضعیت

چهار منطقه `garden`، `school`، `park` و `city`؛ هر کدام شش بستر. حداقل فصل باز شدن: `garden=1`، `school=4`، `park=6`، `city=7`. `set_zone()` فقط منطقه و موقعیت بازیکن را عوض می‌کند و فصل فعال را تغییر نمی‌دهد.

نسخهٔ فعلی ذخیره `SAVE_VERSION = 3` است. حالت بازی تازه شامل فصل، منطقه، روز، `time_of_day`، امتیازها، منابع، پیشرفت مأموریت، یادبودها، پرسش‌ها، آموزش‌ها، روایت‌های دیده‌شده، ایستگاه کمپوست و موقعیت بازیکن است. هر بستر فیلدهایی مثل `prepared`، `species`، `stage`، رطوبت، خاک، سلامت، رشد، `dead` و `neglect_days` دارد. `stage=0` بستر خالی است و نهال کاشته‌شده مراحل `1..5` را دارد.

تنظیمات جدا از ذخیرهٔ بازی در `user://settings.cfg` نگهداری می‌شوند: `music`، `sound`، `touch`، `reduced_motion` و `day_length` (۱۲۰ تا ۴۸۰ ثانیه؛ پیش‌فرض ۲۴۰). `new_game()` این تنظیمات را حفظ می‌کند.

## رشد و چرخهٔ روز

آماده‌سازی خاک، کاشت (مصرف یک بذر)، آبیاری و کمپوست (یک‌بار در روز برای هر بستر) وضعیت نهال را تغییر می‌دهد. رشد فقط با `advance_day()` انجام می‌شود و به ساعت واقعی یا اینترنت وابسته نیست. هوا بر اساس `day % 4` یکی از حالت‌های آفتابی، نیمه‌ابری یا بارانی است. رشد به رطوبت، خاک، نور و نیاز گونه بستگی دارد؛ نهال بی‌مراقبت ممکن است بمیرد و بستر دوباره آزاد شود. رویداد `mature_tree` وقتی ثبت می‌شود که `stage >= 4` و `health >= 60` باشد.

## یادبود

`save_memorial(zone, index, name_text, message)` یک پلاک محلی می‌سازد. نام و پیام نباید خالی باشند (سقف ۴۰ و ۲۴۰ نویسه)، بستر باید گونه داشته باشد و پلاک تکراری پذیرفته نمی‌شود. یک ایجاد موفق هم‌زمان `write_memorial` و `add_memorial` را پیش می‌برد و فوراً ذخیره می‌کند. ویرایش و حذف در این نسخه وجود ندارد.

## ذخیره و بازیابی

مسیرها:

```text
user://garden.save
user://garden.backup
user://settings.cfg
```

فایل ذخیره یک envelope است: رشتهٔ `payload` (JSON وضعیت) و `checksum` که SHA-256 همان رشته است. نسخهٔ داخل payload برابر ۳ است و ذخیره‌های نسخهٔ ۱ و ۲ هنگام بارگذاری مهاجرت می‌کنند.

ترتیب ذخیره: نوشتن envelope در فایل موقت، بررسی خطای نوشتن و `flush()`، کپی primary معتبر به `backup + ".tmp"`، اعتبارسنجی backup موقت و rename اتمی آن، سپس جایگزینی primary با rename. در شکست، فایل موقت حذف، `dirty` حفظ و خطا اعلام می‌شود؛ primary یا backup معتبر قبلی دست‌نخورده می‌ماند. `path_override` برای تست است و backup عادی نمی‌سازد.

`load_game()` ابتدا فایل اصلی و در صورت نیاز backup را می‌خواند. `has_valid_save()` فقط وقتی Continue را مجاز می‌کند که یکی از این دو معتبر باشد. حداکثر اندازهٔ فایل خواندنی ۲٬۰۰۰٬۰۰۰ بایت است.

نقاط ذخیره شامل بازی تازه، پایان فصل، پایان روز، ایجاد یادبود، نخستین خواندن روایت، ذخیرهٔ دستی، بازگشت به منو و خروج است. تغییرات گیم‌پلی با timer ده‌ثانیه‌ای ذخیره می‌شوند؛ تغییر فقط ساعت هر ۶۰ ثانیه یک‌بار ذخیره می‌شود. خطای autosave با اعلان throttle‌شده گزارش می‌شود.

## جهان و کنترل‌ها

`WorldController` فضای ۱۲۸۰×۷۲۰ را بدون TileMap می‌سازد: شش بستر، چهار NPC، پسماند، آب‌پاش و ایستگاه کمپوست. هر فصل پس‌زمینهٔ اختصاصی `scene_<name>.svg` دارد؛ اگر مکان فعال با مکان آن فصل یکی نباشد، از `DEFAULT_SCENES` استفاده می‌شود. فاصلهٔ تعامل ۱۱۵ است. `PlayerController` حرکت را با برخورد بسترها، موانع صحنه و NPCها محدود می‌کند. سفر بین نقشه‌ها و بازدید نهال، world فعال را در جای خود refresh می‌کند و screen/HUD را از نو نمی‌سازد.

`GameAtlas` اطلس‌های SVG (از جمله `plants.svg`، `npcs.svg`، `player.svg`، `icons.svg` و `props.svg`) را cache می‌کند. `tiles.svg` هنوز تولید می‌شود، اما پس از آمدن پس‌زمینه‌های کامل فصل در رسم جهان استفاده نمی‌شود.

| عمل | لمسی | صفحه‌کلید |
| --- | --- | --- |
| حرکت | جوی‌استیک پایین چپ | `WASD` یا کلیدهای جهت‌دار |
| تعامل | لمس هدف یا دکمهٔ «عمل» | `E` یا `Space` |
| آبیاری | دکمهٔ «آب» یا دکمهٔ کنار نهال | `Q` |
| توقف | دکمهٔ «توقف» | `Escape` |
| بازگشت اندروید | `NOTIFICATION_WM_GO_BACK_REQUEST` | بستن مودال، توقف یا تأیید خروج |

جوی‌استیک ورودی را با `make_input_local()` به فضای کنترل تبدیل می‌کند و لغو لمس Android را reset می‌کند. `TouchActionButton` هر انگشت Action/Water را مستقل ثبت می‌کند؛ خروج انگشت از rect یا release ماوس خارج از دکمه، action را لغو می‌کند. InputMap سفارشی تعریف نشده و کلیدها مستقیماً خوانده می‌شوند. رفتار Back روی دستگاه فیزیکی هنوز تأیید نشده است.

## رابط و صدا

`main.gd` همهٔ صفحه‌ها و مودال‌ها را در زمان اجرا می‌سازد؛ stack صفحه حفظ نمی‌شود. متن‌های کاربردی فارسی و راست‌چین‌اند؛ مقدار منابع HUD وسط‌چین است و آدرس لاتین منبع LTR می‌ماند. منو و ending از تصویر سینمایی با shader زمان‌واقعی استفاده می‌کنند، نه فایل ویدئو. `reduced_motion` حرکت اتمسفر را کم می‌کند و `touch` نمایش کنترل لمسی را قطع و وصل می‌کند. chipهای HUD پس از ساخت اولیه در جای خود به‌روزرسانی می‌شوند.

`AudioManager` دو پخش‌کنندهٔ موسیقی با crossfade، دو ambience و شش پخش‌کنندهٔ SFX دارد. توقف بازی صدا را قطع می‌کند؛ تنظیمات بازشده از توقف، ساعت را متوقف نگه می‌دارد ولی صدا را برای پیش‌نمایش فعال می‌کند. هنگام استفادهٔ مجدد از همان stream باد، gain مکان جدید بدون restart اعمال می‌شود.

## تست و خروجی اندروید

تست خودکار با این فرمان اجرا می‌شود:

```bash
godot --headless --path . --scene res://tests/test_runner.tscn
```

نتیجهٔ تأییدشده در ۲۰۲۶-۱۱-۲۷:

```text
ROOTS_TESTS: 359 checks, 0 failures
```

پوشش شامل منطق بازی، محتوا، ذخیره و migration، UI smoke، چرخهٔ حیات، چندلمسی، لغو لمس، استفادهٔ مجدد HUD/world و شکست‌های ذخیره است. `tools/build_android.sh` پیش از export همین suite را اجرا می‌کند و در صورت خطا ساخت APK را متوقف می‌کند.

جزئیات پوشش، پذیرش و آزمون دستگاه در [آزمون و پذیرش](TESTING.md)، [گزارش آزمون](TEST_REPORT.md) و [گزارش بازرسی فنی](QA_AUDIT.md) آمده است. ساخت، امضا و نصب APK در [راهنمای ساخت اندروید](ANDROID_BUILD.md) توضیح داده شده است.
