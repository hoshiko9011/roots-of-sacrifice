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
| ---: | --- | --- | --- |
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

آماده‌سازی خاک، کاشت (مصرف یک بذر)، آبیاری و کمپوست (یک‌بار در روز برای هر بستر) وضعیت نهال را تغییر می‌دهند. رشد فقط با `advance_day()` انجام می‌شود و به ساعت واقعی یا اینترنت وابسته نیست. هوا بر اساس `day % 4` یکی از حالت‌های آفتابی، نیمه‌ابری یا بارانی است. رشد به رطوبت، خاک، نور و نیاز گونه بستگی دارد؛ نهال بی‌مراقبت ممکن است بمیرد و بستر دوباره آزاد شود. رویداد `mature_tree` وقتی ثبت می‌شود که `stage >= 4` و `health >= 60` باشد.

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

ترتیب ذخیرهٔ عادی: نوشتن در فایل موقت، `flush`، اگر ذخیرهٔ فعلی معتبر باشد کپی آن به backup، سپس جایگزینی با rename. اگر ساخت backup شکست بخورد، ذخیرهٔ اصلی جایگزین نمی‌شود. `path_override` برای تست است و backup عادی نمی‌سازد.

`load_game()` ابتدا فایل اصلی و در صورت نیاز backup را می‌خواند. `has_valid_save()` فقط وقتی Continue را مجاز می‌کند که یکی از این دو معتبر باشد. حداکثر اندازهٔ فایل خواندنی ۲٬۰۰۰٬۰۰۰ بایت است.

نقاط ذخیره شامل بازی تازه، پایان فصل، پایان روز، ایجاد یادبود، نخستین خواندن روایت، ذخیرهٔ دستی، بازگشت به منو، خروج، و یک timer ده‌ثانیه‌ای برای حالت dirty است. شکست ذخیره، بازی تازه یا خروج را متوقف می‌کند.

## جهان و کنترل‌ها

`WorldController` فضای ۱۲۸۰×۷۲۰ را بدون TileMap می‌سازد: شش بستر، چهار NPC، پسماند، آب‌پاش و ایستگاه کمپوست. هر فصل پس‌زمینهٔ اختصاصی `scene_<name>.svg` دارد؛ اگر مکان فعال با مکان آن فصل یکی نباشد، از `DEFAULT_SCENES` استفاده می‌شود. فاصلهٔ تعامل ۱۱۵ است. `PlayerController` حرکت را با برخورد بسترها، موانع صحنه و NPCها محدود می‌کند.

`GameAtlas` اطلس‌های SVG (از جمله `plants.svg`، `npcs.svg`، `player.svg`، `icons.svg` و `props.svg`) را cache می‌کند. `tiles.svg` هنوز تولید می‌شود، اما پس از آمدن پس‌زمینه‌های کامل فصل در رسم جهان استفاده نمی‌شود.

| عمل | لمسی | صفحه‌کلید |
| --- | --- | --- |
| حرکت | جوی‌استیک پایین چپ | `WASD` یا کلیدهای جهت‌دار |
| تعامل | لمس هدف یا دکمهٔ «عمل» | `E` یا `Space` |
| آبیاری | دکمهٔ «آب» یا دکمهٔ کنار نهال | `Q` |
| توقف | دکمهٔ «توقف» | `Escape` |
| بازگشت اندروید | `NOTIFICATION_WM_GO_BACK_REQUEST` | بستن مودال، توقف یا تأیید خروج |

InputMap سفارشی تعریف نشده و کلیدها مستقیماً خوانده می‌شوند. رفتار Back روی دستگاه فیزیکی هنوز تأیید نشده است.

## رابط و صدا

`main.gd` همهٔ صفحه‌ها و مودال‌ها را در زمان اجرا می‌سازد؛ stack صفحه حفظ نمی‌شود. متن‌های کاربردی فارسی و راست‌چین‌اند؛ مقدار منابع HUD وسط‌چین است و آدرس لاتین منبع LTR می‌ماند. منو و ending از تصویر سینمایی با shader زمان‌واقعی استفاده می‌کنند، نه فایل ویدئو. `reduced_motion` حرکت اتمسفر را کم می‌کند و `touch` نمایش کنترل لمسی را قطع و وصل می‌کند.

`AudioManager` دو پخش‌کنندهٔ موسیقی با crossfade، دو ambience و شش پخش‌کنندهٔ SFX دارد. توقف بازی صدا را قطع می‌کند؛ تنظیمات بازشده از توقف، ساعت را متوقف نگه می‌دارد ولی صدا را برای پیش‌نمایش فعال می‌کند.

## تست و خروجی اندروید

تست خودکار با این فرمان اجرا می‌شود:

```bash
godot --headless --path . --scene res://tests/test_runner.tscn
```

جزئیات پوشش، پذیرش و آزمون دستگاه در [آزمون و پذیرش](TESTING.md) و [گزارش آزمون](TEST_REPORT.md) آمده است. ساخت، امضا و نصب APK در [راهنمای ساخت اندروید](ANDROID_BUILD.md) توضیح داده شده است./دسترسی، درصد زنده، توضیح کلیدها، بازنشانی و پیوند راهنمای کنترل دارد. گزینه‌های master volume، mute، متن بزرگ، کنتراست بالا و دست چپ وجود ندارند.

## ۶. قواعد بازی و رشد

- آماده‌سازی نخست: `prepared=true`، `soil=65`، `eco += 2`.
- کمپوست: یک‌بار در روز برای هر بستر؛ یک واحد مصرف، `soil += 20` تا ۱۰۰ و `health += 10` تا ۱۰۰.
- کاشت: یک seed، `stage=1`، `moisture=20` و پاداش اکوی گونه.
- آبیاری: اگر همان روز آب داده شده یا رطوبت دست‌کم ۷۰ باشد مسدود؛ در غیر این صورت یک water، `moisture += 45`، `health += 10` و `eco += 2`.
- آب‌پاش به ۸ برمی‌گردد. جمع پسماند یک compost تا سقف ۱۲ و `eco += 2` می‌دهد.
- کمک به NPC: `social += 3`، یک آمار کمک و یک compost تا سقف ۱۲.
- NPC راهنما اگر seeds کمتر از ۶ باشد آن را به ۶ می‌رساند.
- `next_chapter()` منابع را به حداقل `water=8`، `seeds=6`، `compost=6` می‌رساند؛ سقف بالایی اعمال نمی‌کند.

هوا بر اساس `day % 4` فقط سه حالت دارد: `آفتابی`، `نیمه‌ابری`، `بارانی`؛ روز `0 mod 4` نیز آفتابی است. هیچ رشد وابسته به زمان واقعی یا آفلاین وجود ندارد.

در `advance_day()`:

1. باران پیش از رشد `moisture += 35` تا سقف ۱۰۰ می‌کند.
2. اگر رطوبت دست‌کم ۲۰ و خاک دست‌کم ۳۵ باشد، رشد انجام می‌شود.
3. ضریب نور `1.0` است اگر `plot.sun >= species.sun_need`؛ در غیر این صورت `0.7`.
4. `growth += sun_factor * (1.0 + soil / 200.0)`.
5. `stage = clamp(1 + int(growth * 4 / growth_actions), 1, 5)`.
6. شرایط سالم `health += 5` می‌دهد؛ شرایط نامساعد `health -= 15` با حداقل ۲۰.
7. رطوبت به اندازهٔ `water_need * 10` کم و خاک ۳ واحد کم می‌شود.

`_check_mature()` برای هر بستر در هر منطقه با `stage >= 4` و `health >= 60` رویداد `mature_tree` ثبت می‌کند. `biodiversity()` گونه‌های سالم را در همهٔ مناطق می‌شمارد، هرچند متن UI آن را «در شهر» نامیده است.

## ۷. یادبود

API:

```gdscript
func save_memorial(zone: String, index: int, name_text: String, message: String) -> bool
```

اعتبارسنجی: نام و پیام پس از حذف فاصله غیرخالی، نام حداکثر ۴۰ و پیام حداکثر ۲۴۰ نویسه، بستر دارای گونه و نبود پلاک قبلی.

```gdscript
{
    "key": zone + ":" + str(index),
    "zone": zone,
    "plot": index,
    "name": name_text.strip_edges(),
    "message": message.strip_edges(),
    "day": data.day,
    "species": plot.species
}
```

یک ایجاد موفق هم‌زمان `write_memorial` و `add_memorial` را یک‌بار پیش می‌برد، `culture += 5` می‌کند، `story_keeper` را باز می‌کند و فوراً ذخیره می‌کند. UI فقط فهرست و ایجاد را پشتیبانی می‌کند؛ ویرایش و حذف وجود ندارد.

## ۸. ذخیره، checksum و بازیابی

### ۸.۱. مسیرها و envelope

```text
user://garden.save
user://garden.backup
user://settings.cfg
```

```json
{
  "payload": "{\"version\":1,\"chapter\":1,...}",
  "checksum": "<SHA-256 hex>"
}
```

`payload` یک رشتهٔ JSON است، نه object. `schema_version` در envelope وجود ندارد. checksum از همان رشتهٔ payload محاسبه می‌شود:

```gdscript
var payload := JSON.stringify(data)
var envelope := JSON.stringify({
    "payload": payload,
    "checksum": payload.sha256_text()
})
```

### ۸.۲. ترتیب ذخیره

1. نوشتن envelope در `target + ".tmp"`.
2. `flush()` و `close()`.
3. در ذخیرهٔ عادی، اگر primary معتبر است، کپی آن به backup.
4. جایگزینی primary با `DirAccess.rename_absolute()`.
5. موفقیت: پاک‌شدن dirty و خطای ذخیره؛ شکست: حفظ خطا و فایل موقت.

محدودیت‌های مهم:

- فایل موقت پیش از rename دوباره خوانده و اعتبارسنجی نمی‌شود.
- خطای کپی backup بررسی نمی‌شود و جایگزینی backup اتمیک نیست.
- اگر rename شکست بخورد، مسیر کپی جایگزین وجود ندارد.
- `path_override` برای تست استفاده می‌شود و backup عادی نمی‌سازد.
- «اتمیک» فقط به معنای جایگزینی rename-based است؛ تضمین در برابر قطع ناگهانی برق اثبات نشده است.

### ۸.۳. اعتبارسنجی و fallback

`_read_save()`:

- حداکثر اندازهٔ فایل ۲٬۰۰۰٬۰۰۰ بایت.
- envelope dictionary با `payload` و `checksum` رشته‌ای.
- تطبیق SHA-256، parse payload و عبور از `_valid_save()`.

`_valid_save()` کلیدهای اصلی، نسخه، فصل، روز، منطقه، طول آرایهٔ بازیکن، نوع چند ساختار، مقادیر منفی امتیاز/منبع، چهار منطقه با شش بستر، فیلدهای بستر، گونهٔ معتبر، مرحلهٔ `0..5` و فیلدهای یادبود را بررسی می‌کند. این بررسی کاملی نیست؛ نوع و معنای همهٔ اعداد، همهٔ ارجاع‌ها، تکراری‌ها، طول متن یادبود و همهٔ invariantها تضمین نمی‌شوند.

`load_game()` اول primary و سپس backup را می‌خواند. backup معتبر پیام فارسی بازیابی می‌دهد. اگر هیچ‌کدام معتبر نباشند، `save_error` تنظیم و `save_available=false` می‌شود. `has_valid_save()` نیز در startup فقط فایل معتبر را برای فعال بودن Continue پذیرفته می‌کند.

### ۸.۴. نقاط ذخیره

- `new_game()`، پایان فصل، فصل بعد، پایان روز، ایجاد یادبود و نخستین خواندن هر روایت NPC فوراً ذخیره می‌کنند.
- timer ده‌ثانیه‌ای، حالت dirty را ذخیره می‌کند.
- ذخیرهٔ دستی، بازگشت به منو، خروج و notificationهای pause/close نیز ذخیره را صدا می‌زنند؛ شکست ذخیره، بازی تازه، منو یا خروج را متوقف می‌کند و پیام خطا نشان می‌دهد.
- بستن پنجرهٔ پایان فصل، مأموریت را برای ادامهٔ فصل نگه می‌دارد؛ Android Back ابتدا مودال را می‌بندد و در جهان توقف را باز می‌کند.
- تنظیمات با تغییر هر کنترل و در `ConfigFile` جداگانه ذخیره می‌شوند.

## ۹. جهان، atlas و کنترل‌ها

### ۹.۱. جهان و بازیکن

`WorldController` فضای مجازی `1280×720` را می‌سازد: شش بستر، چهار NPC، هشت پسماند، یک آب‌پاش و چند prop. فاصلهٔ تعامل ۱۱۵ واحد است. TileMap و collision shape استفاده نمی‌شود.

- هر هشت فصل یک تصویر کامل `1280×720` با نام `scene_<chapter>.svg` دارد: باغ فراموش‌شده، نخستین نهال، خاک و آب، حیاط مدرسه، باغ یادبود، پارک محله، شهر سبز و مسئولیت‌پذیری شهری.
- صحنهٔ فصل فقط وقتی انتخاب می‌شود که مکان فعال با مکان همان فصل یکی باشد؛ بازدید از مکان دیگر از `DEFAULT_SCENES` استفاده می‌کند تا صحنهٔ یادبود یا شهر در مکان اشتباه نشان داده نشود.
- هر صحنه یک دادگاه کاشت مشترک با شش بستر دارد؛ مسیرها، درختان و بنای تزئینی از این محدوده بیرون می‌مانند و بسترهای اجرایی همیشه روی آن قرار می‌گیرند.
- `PlayerController` سرعت ۱۸۰، محدودهٔ `Rect2(120, 200, 1050, 435)`، مانعهای ویژهٔ هر صحنه، برخورد شش بستر و propهای ثابت و دایرهٔ دور NPC دارد؛ مسیرهای تعامل زیر و کنار بسترها باز می‌مانند.
- `weather_overlay.svg` در کد اجرایی استفاده نمی‌شود.
- حرکت با گام‌های کوچک محور جدا انجام می‌شود تا tunneling رخ ندهد؛ click-to-walk و teleport وجود ندارد.

### ۹.۲. atlas

| فایل | ابعاد | شبکه |
|---|---:|---|
| `tiles.svg` | `512×256` | ۸×۴ سلول ۶۴ |
| `player.svg` | `256×384` | ۴×۶ سلول ۶۴ |
| `npcs.svg` | `384×256` | ۶×۴ سلول ۶۴ |
| `plants.svg` | `512×384` | ۸×۶ سلول ۶۴؛ فقط شش ستون اول |
| `props.svg` | `512×256` | ۸×۴ سلول ۶۴ |
| `icons.svg` | `512×128` | ۱۶×۴ سلول ۳۲ |

ردیف‌های بازیکن: `down/up/left/right/water/plant`؛ ستون‌های انیمیشن `0..3`.

NPCهای جهان از ستون‌های `0,1` و ردیف‌های `0..3` برای idle استفاده می‌کنند. پرترهٔ دیالوگ از ستون `2` و همان ردیف‌ها می‌آید؛ ستون‌های `3..5` استفاده نمی‌شوند.

ردیف درخت: `cypress=0`، `native_oak=1`، `pomegranate=2`، `arghavan=3`، `olive=4`، `willow=5`؛ ستون مرحله `0..5`.

نگاشت آیکون‌ها:

```text
ردیف 0: leaf(0)، heart(1)، book(2)، star(3)، water(4)، soil(5)، sun(6)، seed(7)
ردیف 1: settings(0)، sound(1)، music(2)، pause(3)، play(4)، back(5)، close(6)، check(7)
ردیف 2: quest(0)، map(1)، memorial(2)، achievement(3)، lock(4)، info(5)، home(6)، chapter(7)، team(8)
ردیف 3: recycle(4)، trash(5)، trophy(6)، sprout(7)
```

تنها این ۲۹ کلید در `ICONS` تعریف شده‌اند.

نگاشت propهای اجرایی:

```text
litter=props(6,0)، recycle=props(7,1)، board=props(5,0)،
bench=props(0,2)، lamp=props(1,2)، birdbath=props(2,2)، compost=props(6,2)
```

آیکون `sprout` از `sprout_icon.svg` می‌آید؛ این فایل تبدیل بدون اتلاف پیکسل منبع ۶۴×۶۴ ساختهٔ صاحب پروژه است. آیکون legacy اندروید نیز از منبع ۲۵۶×۲۵۶ همان کاربر با حفظ رنگ و شفافیت ساخته می‌شود. نسخه‌های adaptive foreground/background و monochrome با silhouet دوبرگ، خاک و ریشه و پالت گرم همان طرح تولید می‌شوند. منبع‌های PNG در `assets/art/source` حفظ و از خروجی Android مستثنا می‌شوند.

`tiles.svg` همچنان در atlas تولید می‌شود، اما پس از افزودن پس‌زمینه‌های کامل فصل‌ها در `WorldController._draw()` استفاده نمی‌شود.

### ۹.۳. کنترل‌ها

- حرکت لمسی: جوی‌استیک پایین چپ؛ حرکت دسکتاپ: `WASD` یا کلیدهای جهت‌دار.
- تعامل لمسی: لمس مستقیم هدف یا دکمهٔ «عمل» در پایین راست؛ معادل دسکتاپ: `E` یا Space.
- آبیاری لمسی: دکمهٔ «آب» در پایین راست یا دکمهٔ آب کنار نهال؛ معادل دسکتاپ: `Q`.
- توقف لمسی: دکمهٔ «توقف» بالای صفحه؛ معادل دسکتاپ: Escape.
- انتخاب بستر با ماوس/لمس وقتی بازیکن نزدیک است؛ `emulate_touch_from_mouse=true`.
- ایستگاه کمپوست در باغ و مدرسه در `COMPOST_POSITION` قرار دارد و هم هدف دکمهٔ «عمل» و هم لمس مستقیم را می‌پذیرد؛ برخورد و وضعیت بصری آن در هر دو مکان به state کمپوست وابسته است.
- جوی‌استیک `150×150` با یک انگشت، deadzone زیر `0.15` و بردار تقسیم بر ۵۲ با طول حداکثر ۱.
- InputMap سفارشی تعریف نشده؛ کلیدهای فیزیکی مستقیم خوانده می‌شوند.
- Android Back با `NOTIFICATION_WM_GO_BACK_REQUEST` مودال فعال را می‌بندد، در جهان توقف را باز می‌کند و در منوی اصلی تأیید خروج می‌دهد؛ اجرای فیزیکی روی دستگاه هنوز بررسی نشده است.

## ۱۰. UI، RTL و صدا

`main.gd` مالک منوی اصلی، HUD، دیالوگ آغاز فصل، همهٔ مودال‌ها، نقشه، تنظیمات، توقف، پرسش، یادبود و ending است. صفحه‌ها در زمان اجرا ساخته می‌شوند. `_clear_screen()` صفحه و جهان قبلی را آزاد می‌کند؛ stack صفحه‌ها حفظ نمی‌شود.

صفحه‌ها و مودال‌های فعلی:

- منوی اصلی و تأیید بازی تازه.
- دیالوگ آغاز فصل و جهان/HUD.
- بستر آماده‌نشده، انتخاب گونه و مراقبت بستر کاشته‌شده.
- دیالوگ NPC، مأموریت‌ها و نقشه.
- مدیریت نهال‌ها.
- فهرست یادبود، انتخاب نهال و نوشتن نام/پیام.
- روایت‌ها، پرسش و دستاوردها.
- زمان خودکار روز/شب، ایستگاه کمپوست، خلاصهٔ پایان فصل و ending.
- توقف، تنظیمات، راهنمای کنترل، «درباره ما» با معرفی نیوتک و اعضای آن و تأیید خروج.
- toast ذخیره، اعلان مأموریت و دستاورد.

باز شدن مودال، جهان را غیرفعال، جوی‌استیک را reset و دکمه‌های لمسی «عمل» و «آب» را disabled می‌کند؛ بستن مودال آن‌ها را دوباره فعال می‌کند. بیشتر مودال‌ها scene tree را pause نمی‌کنند. فقط `_pause()` صریحاً `get_tree().paused=true` می‌کند. صفحهٔ «درباره ما» از پنل ۹۰۰×۶۸۰ با `about_panel.svg`، آیکون گروه، کارت دو عضو، شعار و رویداد استفاده می‌کند؛ دکمهٔ × حداقل ۶۴×۶۴ است و overlay ورودی منوی زیرین را می‌گیرد. بنر عنوان منو از `title_panel.svg` با قاب چوبی، زمینهٔ سبز تیره، نشان نهال/ریشه و تزئینات برگی استفاده می‌کند؛ عنوان و زیرعنوان در ناحیهٔ راست‌چین و تک‌خطی قرار می‌گیرند. منوی اصلی و ending هر دو `cinematic_garden.png` را با `cinematic_garden.gdshader` نمایش می‌دهند؛ shader همان تصویر ۱۷۹۲×۱۰۲۴ را با حفظ نسبت و pixel sampling، زوم ۱٫۸٪ در ۱۲ ثانیه، حرکت ظریف برگ/گل/ابر، تکان شال، جریان فواره، موج و انعکاس طلایی آب متحرک می‌کند. ماسک تقریبی شخصیت او را ثابت نگه می‌دارد و `reduced_motion` یا توقف بازی حرکت را متوقف می‌کند. این پیاده‌سازی ویدئوی فشرده نیست؛ انیمیشن زمان‌واقعی و آفلاین است.

`UIFactory` برچسب و دکمه‌های RTL، `VBoxContainer/HBoxContainer` راست‌به‌چپ، ارقام فارسی، panel، image و progress می‌سازد. تمام متن‌ها و دکمه‌های کاربردی راست‌چین‌اند؛ مقدار و برچسب متن داخل chipهای HUD برای خوانایی وسط‌چین‌اند و برچسب لاتین آدرس منبع عمداً LTR و چپ‌چین می‌ماند. حداقل ارتفاع دکمهٔ استاندارد ۵۶ است؛ هدف لمس عمومی ۶۴×۶۴ وجود ندارد. تمام containerهای خام لازم هم RTL نیستند.

منوی اصلی، کنترل‌های درون بازی و دو اقدام صفحهٔ Ending از `TextureButton` با سه تصویر مستقل normal/hover/pressed استفاده می‌کنند. دکمه‌های استاندارد مودال و لمسی نیز در `UIFactory.button()` از `StyleBoxTexture` با همان خانوادهٔ چوب/برگ و سه حالت استفاده می‌کنند؛ آب و خطر تصویر اختصاصی دارند. `_title_button()` آیکون و برچسب فارسی را به‌صورت فرزند می‌سازد؛ `_quest_label` متن ردیاب مأموریت را جدا از `TextureButton.text` به‌روز می‌کند. `hud_panel.svg` پس‌زمینهٔ منابع و ساعت است و `_hud_chip()` هر گروه را با `hud_chip.svg` می‌سازد؛ آیکون و مقدار در ردیف بالا و نام منبع با برچسب تک‌خطی فونت ۱۰ در پایین همان chip قرار می‌گیرد. نقشه، توقف، مأموریت و سه اقدام نوار پایین با `button_hud`، `button_quest` و `button_compact` هم‌سبک منوی اصلی هستند.

دیالوگ هر چهار NPC دکمه‌های «گفتگو» و «داستان» دارد. `_open_story()` همهٔ روایت‌ها را با روایت شخص اول همان NPC نمایش می‌دهد؛ برای روایت واقعی، نام شهید، ارجاع به روایت‌گوی اصلی، عنوان و دامنهٔ منبع دیده می‌شود و آدرس کامل در tooltip و دادهٔ `NPC_STORIES` باقی می‌ماند؛ برای رها، برچسب «روایت تخیلی» و پیام روشنِ غیرتاریخی نشان داده می‌شود و منبع ساختگی ساخته نمی‌شود. «روایت بعدی» فصل بعد را در همان NPC باز می‌کند و پس از فصل ۸ به فصل ۱ برمی‌گردد. این روایت‌ها متنی‌اند و صدای گفتاری تولید نمی‌کنند.

`reduced_motion` فقط اتمسفر، تعویض frame idleNPC و تعداد ذرهٔ باران را کم می‌کند؛ همهٔ انیمیشن‌ها را خاموش نمی‌کند. `touch` نمایش جوی‌استیک و دکمه‌های لمسی «عمل» و «آب» را کنترل می‌کند.

`AudioManager` دو پخش‌کنندهٔ موسیقی با crossfade، دو ambience و شش SFX round-robin دارد و bus سفارشی نمی‌سازد. چهار MP3 ارائه‌شدهٔ `title/garden/rain/path` بر اساس صحنه، شب و هوا انتخاب و در runtime حلقه می‌شوند. SFXهای فعال: `click/steps/prepare/plant/grow/water/harvest/save/unlock/quiz_correct/quiz_wrong/birds`.

```text
music volume = music × 0.4
ambience volume = sound × 0.1
SFX volume = sound × 0.55
```

صفر کردن موسیقی یا صدا، stream مربوط را pause می‌کند. `set_paused(true)` موسیقی و ambience را pause و SFXها را stop می‌کند. هنگام توقف بازی همهٔ صداها قطع می‌شوند؛ اگر از توقف به تنظیمات رفت، ساعت متوقف می‌ماند ولی صدا برای پیش‌نمایش دوباره فعال می‌شود. `shutdown()` همهٔ پخش‌کننده‌ها را متوقف، streamها را آزاد و cache را پاک می‌کند؛ پیش از خروج عادی بازی و در `_exit_tree()` صدا زده می‌شود. در درایور `headless`، `play_music()` و `play_sfx()` بی‌اثرند تا پخش‌کننده‌ها در teardown موتور نشت نکنند؛ این محدودیت فقط محیط تست است. پرندگان تصادفی در باغ، مدرسه و پارک، `sfx_water_loop` در شهر و باد/باران در محیط مناسب پخش می‌شوند.

## ۱۱. تست خودکار

ساختار فعلی فقط `tests/run_tests.gd` و `tests/test_runner.tscn` است. فرمان:

```sh
./tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --scene res://tests/test_runner.tscn
```

نتیجهٔ تأییدشده در ۲۰۲۶-۱۱-۲۶:

```text
ROOTS_TESTS: 325 checks, 0 failures
```

پوشش: وضعیت اولیه، چهار منطقه، شش بستر هر منطقه، هشت فصل از راه APIهای عمومی، انتخاب صحنهٔ درست برای هر هشت فصل، fallback صحیح هنگام بازدید از مکان دیگر، شش بستر قابل‌دسترسی در هر صحنه، فاصلهٔ ۱۲۰ پیکسلی ردیف‌ها و نبود هم‌پوشانی hit area، هر ۳۰ مأموریت، جلوگیری از پایان تکراری، گفت‌وگوی تکراری فصل ۱، پایان فصل ۸، round-trip ذخیره، backup، ذخیرهٔ خراب، چرخهٔ خودکار زمان، مراقبت/مرگ/کاشت دوبارهٔ نهال، کمپوست، آموزش اولیه یک‌باره و آموزش خودکار فقط برای ویژگی‌های تازه، ۱۵ WAV، چهار MP3، ۱۵ تصویر دکمهٔ عنوان، ۹ تصویر دکمهٔ درون بازی، ۶ تصویر اختصاصی دکمهٔ آب/خطر، قاب و chip منابع و ۳۲ روایت NPCها شامل ۲۴ روایت واقعی منبع‌دار و هشت روایت تخیلی رها. UI smoke همچنین منو، باز شدن «درباره ما» از دکمهٔ واقعی و بستن آن با ×، محتوای نیوتک، تنظیمات، راهنما، تأیید خروج، دیالوگ آغاز، مأموریت، نقشه، مدیریت نهال، یادبود، انتخاب گونه، روایت، پرسش، دستاوردها، کمپوست، NPC، تعامل بستر، توقف، ذخیرهٔ دستی، ending، ادامه و تأیید بازی تازه را با صحنهٔ واقعی می‌سازد؛ برای یک پرسش، پاسخ نادرست و سپس درست را بررسی می‌کند. تست‌های رگرسیون، حفظ توقف در Settings، پنهان شدن جوی‌استیک زیر مودال، رکورد بدشکل یادبود، آزادسازی ActionBurst، صدا headless، شکست ساخت backup، بن‌بست فصل ۵، پیشرفت فصل‌محور روایت‌ها و تعامل کمپوست مدرسه با عمل/لمس را نیز پوشش می‌دهند. متن و دکمه‌های فارسی در صفحه‌های کلیدی از نظر RTL و راست‌چین بودن بررسی می‌شوند؛ آدرس لاتین منبع عمداً LTR است.

پیش از خروج تست، `AudioManager.shutdown()`، دو فریم انتظار و ۰٫۱۵ ثانیه فرصت آزادسازی thread صدا اجرا می‌شود؛ سه اجرای متوالی و یک اجرای verbose بدون هشدار ObjectDB تمام شدند. محدودیت: تست مستقیماً `_read_save()` و `_valid_save()` را نیز صدا می‌زند و کاملاً public-API-only نیست. UI smoke عمدتاً فراخوانی مستقیم متدهاست، نه کلیک کامل یا بازبینی بصری همهٔ صفحه‌ها. RTL و چیدمان در ۳۷ تصویر دسکتاپ بررسی شد، اما لمسی، Android Back، کارایی، نصب و سناریوهای بیشتر خرابی ذخیره روی دستگاه پوشش داده نشده‌اند. جزئیات پذیرش در [TESTING.md](TESTING.md) است.

## ۱۲. خروجی و امضای Android

### ۱۲.۱. presetها

| گزینه | مقدار فعلی |
| --- | --- |
| نام preset | `Android Debug`، `Android Release` |
| Package | `ir.roots_of_sacrifice.game` |
| نسخه | `1.0.0`، code `1` |
| ABI | `arm64-v8a`، `armeabi-v7a` |
| Renderer | GL Compatibility پروژه |
| Gradle build | خاموش |
| Signing در preset | `package/signed=false` |
| خروجی unsigned | `builds/android/roots-of-sacrifice-{debug,release}-unsigned.apk` |
| مجوزها | همهٔ گزینه‌های مجوز، از جمله INTERNET، خاموش |
| Min/Target در preset | خالی؛ manifest نهایی ۲۴/۳۶ دارد |

فیلتر خروجی، `tools`، `docs`، `tests`، `vibe_images`، `builds`، `assets/art/source` و فایل موقت توسعهٔ `.character-art-before.json` را حذف می‌کند. وجود این فایل موقت در APK نهایی بررسی و رد شده است.

### ۱۲.۲. جریان `tools/build_android.sh`

1. بررسی Godot، Android build-tools، JDK، `zipalign`، `apksigner`، `aapt2`، `jar`، `unzip` و فایل‌های امضا.
2. import پروژه.
3. export unsigned هر دو preset.
4. افزودن `res/mipmap-anydpi-v26/themed_icon.xml` از `icon.xml` به APK unsigned.
5. `zipalign -p -f 4` و تولید نسخهٔ aligned.
6. `apksigner sign` با keystore دیباگ و release؛ رمز release از فایل محلی و متغیر محیطی خوانده می‌شود.
7. `zipalign -c -p 4` و `apksigner verify --verbose --print-certs`.
8. استخراج badging/permissions با `aapt2`، بررسی package/ABI/نبود هر `uses-permission`، وجود `assets.sparsepck` و اسکریپت اصلی، نبود فایل موقت توسعه و نوشتن SHA-256.

هیچ رمز، keystore یا محتوای فایل رمز نباید در سند، خروجی تست یا مخزن قرار بگیرد.

### ۱۲.۳. شواهد فعلی و محدودیت‌ها

در ۲۰۲۶-۱۱-۲۶ هر دو APK نهایی با ابزارهای صریح JDK 21 و Android Build Tools 36.0.0 ساخته، align و امضا شدند. `apksigner verify` برای هر دو Scheme v2 و v3 را تأیید کرد؛ `aapt2` نام بسته، نسخه، SDK و ABIها را خواند و خروجی permissions فقط نام بسته را داشت. دادهٔ Godot در قالب `assets/assets.sparsepck` و فایل‌های exported مانند `assets/scripts/main.gdc` داخل APK وجود دارد.

- Package: `ir.roots_of_sacrifice.game`؛ نسخه `1.0.0`، code `1`.
- SDK: min `24`، target/compile `36`.
- ABI: `arm64-v8a` و `armeabi-v7a`.
- SHA-256 گواهی release: `cc66b06d152fffe334ae588627fcc05ed353256d3b9b7b233fd759026cef0a3c`.
- SHA-256 گواهی debug: `09d3503eed310908717972f2ff21fc90fcc20346e0dfb35d60cdd1c2eec97f3c`.
- `themed_icon.xml` هم‌نام با `icon.xml` در بسته قرار گرفت و هشدار جدول منابع Godot 4.7.2 دیگر صادر نمی‌شود.
- هیچ `android.permission.INTERNET` یا `uses-permission` دیگری در manifest نهایی دیده نشد.

در ۲۰۲۶-۱۱-۲۶ نسخهٔ release روی Poco X7 Pro فیزیکی (`2412DPC0AG`، Android 16، Mali-G720) نصب و اجرا شد؛ بازی جدید و اجرای دوبارهٔ ذخیره بدون کرش و بدون خطای Godot انجام شد. کرش قبلی ناشی از انتخاب MP3 ناموجود به‌جای WAV imported بود و با `ResourceLoader.exists` و جلوگیری از ارسال stream خالی به پخش‌کننده رفع شد. بازگشت از تنظیماتِ توقف به توقف و بازیابی صدا پس از focus نیز تست می‌شود. Samsung/Huawei فیزیکی، armv7 و GPUهای Adreno/PowerVR هنوز شاهد ندارند؛ بنابراین سازگاری همهٔ گوشی‌ها ادعا نمی‌شود. اندازه و SHA-256 نهایی APKها در [TEST_REPORT.md](TEST_REPORT.md) و [ANDROID_BUILD.md](ANDROID_BUILD.md) ثبت شده است. انطباق با قوانین رسمی مسابقه بررسی نشده و ادعا نمی‌شود.
