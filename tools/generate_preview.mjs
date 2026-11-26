import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const outDir = 'C:/Users/Yasamin/.qoder/app/chat-session-visualizations/b1e638d5-63c6-4a84-b2a7-446833eb7afa/visualizations';
const outFile = path.join(outDir, 'roots-of-sacrifice-preview-20261124.html');
// Encode a local project file as a data URI for a network-independent preview.
const dataUri = (file, mime) => `data:${mime};base64,${fs.readFileSync(path.join(root, file)).toString('base64')}`;

// Load pre-rasterized sprite sheets and embed all assets required by the preview.
const raster = JSON.parse(fs.readFileSync(path.join(root, 'tools/preview_assets.json'), 'utf8'));
const assets = {
  title: dataUri('tools/title_preview.jpg', 'image/jpeg'),
  logo: raster.logo,
  tiles: raster.tiles,
  player: raster.player,
  npcs: raster.npcs,
  plants: raster.plants,
  props: raster.props,
  fontRegular: dataUri('assets/fonts/Vazirmatn-Regular.woff2', 'font/woff2'),
  fontBold: dataUri('assets/fonts/Vazirmatn-Bold.woff2', 'font/woff2'),
};

// Assemble the title, garden, and gallery markup with replaceable asset placeholders.
const html = String.raw`<div id="roots-preview" class="roots-preview" dir="rtl">
  <style>
    @font-face{font-family:Vazir;src:url('__FONT_REGULAR__') format('woff2');font-weight:400;font-display:swap}
    @font-face{font-family:Vazir;src:url('__FONT_BOLD__') format('woff2');font-weight:700;font-display:swap}
    .roots-preview{--ink:#f7efd9;--muted:#b9c9b8;--forest:#102b23;--forest-2:#173f35;--leaf:#86ad59;--gold:#e7b967;--aqua:#63c6bd;--brick:#b96d49;--panel:rgba(16,43,35,.94);--line:rgba(247,239,217,.16);font-family:Vazir,Tahoma,sans-serif;color:var(--ink);background:#091d18;border:1px solid var(--line);border-radius:20px;padding:14px;line-height:1.65;box-sizing:border-box}
    .roots-preview *{box-sizing:border-box}
    .roots-preview button{font:inherit;cursor:pointer}
    .preview-head{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:2px 4px 12px;flex-wrap:wrap}
    .preview-kicker{font-size:12px;color:var(--muted)}
    .preview-title{font-size:17px;font-weight:700}
    .status-badge{display:inline-flex;align-items:center;gap:7px;border:1px solid rgba(99,198,189,.4);background:rgba(99,198,189,.1);color:#a8e5df;border-radius:999px;padding:5px 11px;font-size:12px}
    .status-dot{width:7px;height:7px;border-radius:50%;background:var(--aqua);box-shadow:0 0 12px rgba(99,198,189,.7)}
    .preview-tabs{display:flex;gap:8px;padding:4px;margin-bottom:12px;background:rgba(255,255,255,.04);border-radius:12px;width:max-content;max-width:100%;overflow:auto}
    .preview-tab{border:0;background:transparent;color:var(--muted);border-radius:9px;padding:8px 15px;white-space:nowrap;font-size:13px}
    .preview-tab.active{background:var(--forest-2);color:var(--ink);box-shadow:inset 0 0 0 1px var(--line)}
    .screen{display:none}.screen.active{display:block}
    .title-frame{position:relative;aspect-ratio:16/9;min-height:330px;border-radius:16px;overflow:hidden;background:var(--forest)}
    .title-bg{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;image-rendering:auto}
    .title-shade{position:absolute;inset:0;background:linear-gradient(90deg,rgba(5,22,17,.78) 0%,rgba(5,22,17,.4) 42%,rgba(5,22,17,.04) 72%),linear-gradient(0deg,rgba(5,22,17,.55),transparent 42%)}
    .title-content{position:absolute;inset:0;display:flex;flex-direction:column;align-items:flex-start;justify-content:center;padding:clamp(20px,5vw,58px);max-width:650px}
    .logo-mark{width:clamp(92px,14vw,150px);height:auto;margin-bottom:2px;filter:drop-shadow(0 8px 20px rgba(0,0,0,.3))}
    .game-name{font-size:clamp(29px,5.6vw,62px);line-height:1.25;font-weight:700;margin:0;color:#fff5dc;text-shadow:0 3px 0 rgba(23,63,53,.7)}
    .game-sub{font-size:clamp(12px,1.6vw,17px);color:#d6e7cb;margin:8px 0 20px;max-width:440px}
    .menu-stack{display:flex;flex-direction:column;gap:9px;width:min(300px,100%)}
    .game-btn{border:1px solid rgba(255,255,255,.18);border-radius:10px;background:rgba(17,54,43,.88);color:var(--ink);padding:10px 18px;text-align:right;font-weight:700;transition:transform .16s ease,background .16s ease;box-shadow:0 5px 0 rgba(4,17,13,.25)}
    .game-btn:hover{transform:translateY(-2px);background:#215a45}.game-btn:active{transform:translateY(1px)}
    .game-btn.primary{background:linear-gradient(180deg,#a9ca6b,#6e9a48);color:#112b22;border-color:#d4e9a7}
    .menu-row{display:flex;gap:8px}.menu-row .game-btn{flex:1;text-align:center}
    .version-tag{position:absolute;bottom:14px;left:16px;font-size:11px;color:rgba(255,255,255,.68);letter-spacing:.02em}
    .garden-shell{background:var(--forest);border-radius:16px;overflow:hidden;border:1px solid var(--line)}
    .hud{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:10px 14px;background:#15382d;border-bottom:1px solid var(--line);flex-wrap:wrap}
    .hud-group{display:flex;gap:7px;flex-wrap:wrap}.hud-pill{display:flex;align-items:center;gap:7px;background:rgba(4,24,18,.45);border:1px solid rgba(255,255,255,.08);padding:5px 10px;border-radius:9px;font-size:12px;white-space:nowrap}
    .hud-dot{width:10px;height:10px;border-radius:3px;background:var(--leaf)}.hud-dot.heart{background:#d87766;border-radius:50%}.hud-dot.book{background:var(--gold)}.hud-dot.star{background:#f2d67b;clip-path:polygon(50% 0,61% 35%,98% 35%,68% 56%,79% 94%,50% 71%,21% 94%,32% 56%,2% 35%,39% 35%)}
    .garden-stage{position:relative;width:100%;aspect-ratio:16/8.4;min-height:300px;background:#5e854c;overflow:hidden;isolation:isolate}
    .garden-grid{position:absolute;inset:0;display:grid;grid-template-columns:repeat(16,1fr);grid-template-rows:repeat(9,1fr)}
    .tile{background-image:url('__TILES__');background-size:800% 400%;image-rendering:pixelated;width:100%;height:100%}
    .world-sprite{position:absolute;background-repeat:no-repeat;image-rendering:pixelated;pointer-events:none;filter:drop-shadow(0 5px 2px rgba(17,43,25,.25))}
    .sprite-player{width:8%;aspect-ratio:1;background-image:url('__PLAYER__');background-size:400% 600%;background-position:0% 0%;z-index:5}
    .sprite-guide{width:8%;aspect-ratio:1;background-image:url('__NPCS__');background-size:600% 400%;background-position:0% 0%;z-index:5}
    .sprite-cypress{width:10%;aspect-ratio:1;background-image:url('__PLANTS__');background-size:800% 600%;background-position:57.142% 0%;z-index:4;transform:translate(-8%,-48%)}
    .sprite-arghavan{width:8%;aspect-ratio:1;background-image:url('__PLANTS__');background-size:800% 600%;background-position:57.142% 60%;z-index:4;transform:translate(-8%,-32%)}
    .quest-card{position:absolute;top:12px;right:12px;width:min(290px,46%);background:rgba(249,238,205,.96);color:#263e30;border:2px solid #d4b879;border-radius:12px;padding:10px 12px;z-index:7;box-shadow:0 7px 0 rgba(17,43,35,.2)}
    .quest-eyebrow{font-size:11px;color:#7c6740;margin-bottom:2px}.quest-title{font-size:14px;font-weight:700}.quest-line{font-size:12px;margin-top:5px}.quest-progress{height:6px;border-radius:99px;background:#d9d5bd;margin-top:8px;overflow:hidden}.quest-progress span{display:block;width:66%;height:100%;background:#6f9a48}
    .dialogue-card{position:absolute;bottom:14px;right:12px;left:12px;max-width:640px;margin:auto;background:rgba(249,238,205,.97);color:#263e30;border:2px solid #d4b879;border-radius:12px;padding:10px 14px;z-index:7;box-shadow:0 7px 0 rgba(17,43,35,.2)}
    .speaker{font-size:12px;color:#7b5c35;font-weight:700}.dialogue-text{font-size:13px;margin-top:1px}
    .joystick{position:absolute;left:20px;bottom:20px;width:82px;height:82px;border-radius:50%;background:rgba(14,43,34,.28);border:2px solid rgba(255,255,255,.26);z-index:8;display:grid;place-items:center}
    .joystick:before{content:'';width:38px;height:38px;border-radius:50%;background:rgba(247,239,217,.45);border:2px solid rgba(255,255,255,.45);box-shadow:0 4px 8px rgba(0,0,0,.15)}
    .action-cluster{position:absolute;right:20px;bottom:20px;display:flex;gap:10px;align-items:flex-end;z-index:8}
    .action-round{width:58px;height:58px;border-radius:50%;border:2px solid rgba(255,255,255,.42);background:rgba(18,58,45,.82);color:#fff3d5;display:grid;place-items:center;font-size:12px;box-shadow:0 5px 0 rgba(9,31,24,.25)}
    .action-round.water{width:70px;height:70px;background:rgba(48,139,158,.88);font-weight:700}
    .gallery-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;margin-top:12px}
    .asset-card{background:#15382d;border:1px solid var(--line);border-radius:13px;padding:10px;min-width:0}
    .asset-window{height:118px;border-radius:9px;background:linear-gradient(180deg,#315e47,#234836);display:grid;place-items:center;overflow:hidden;position:relative}
    .asset-window:after{content:'';position:absolute;left:12%;right:12%;bottom:15px;height:8px;border-radius:50%;background:rgba(0,0,0,.17)}
    .asset-sprite{width:92px;height:92px;background-repeat:no-repeat;image-rendering:pixelated;z-index:1}
    .asset-name{font-size:13px;font-weight:700;margin-top:8px}.asset-note{font-size:11px;color:var(--muted);line-height:1.6}
    .scope-strip{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-top:12px}
    .scope-item{background:rgba(255,255,255,.04);border:1px solid var(--line);border-radius:11px;padding:10px;text-align:center}.scope-num{font-size:22px;font-weight:700;color:#d8e9ae}.scope-label{font-size:11px;color:var(--muted)}
    .preview-note{display:flex;align-items:flex-start;gap:8px;padding:11px 5px 1px;color:var(--muted);font-size:12px}.note-mark{width:7px;height:7px;margin-top:8px;border-radius:50%;background:var(--gold);flex:0 0 auto}
    .toast{position:fixed;bottom:24px;left:50%;transform:translateX(-50%) translateY(20px);background:#f4e4bd;color:#173f35;border-radius:10px;padding:9px 16px;font-size:12px;opacity:0;pointer-events:none;transition:.2s ease;z-index:20;box-shadow:0 8px 30px rgba(0,0,0,.3)}
    .toast.show{opacity:1;transform:translateX(-50%) translateY(0)}
    @media(max-width:720px){.roots-preview{padding:9px;border-radius:14px}.title-frame{min-height:390px}.title-content{justify-content:flex-end;padding:22px;max-width:100%}.title-shade{background:linear-gradient(0deg,rgba(5,22,17,.92),rgba(5,22,17,.2) 75%)}.logo-mark{width:78px}.game-name{font-size:34px}.game-sub{margin-bottom:12px}.gallery-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.garden-stage{min-height:330px;aspect-ratio:auto}.quest-card{width:58%;top:8px;right:8px}.dialogue-card{left:86px;right:8px;bottom:12px}.joystick{left:10px;bottom:14px;width:66px;height:66px}.action-cluster{right:10px;bottom:92px}.action-round{width:46px;height:46px}.action-round.water{width:56px;height:56px}.scope-strip{grid-template-columns:repeat(2,1fr)}}
    @media(prefers-reduced-motion:reduce){.roots-preview *{transition:none!important}}
  </style>
  <div class="preview-head">
    <div><div class="preview-kicker">پیش‌نمایش پروژهٔ «ریشه‌های ایثار»</div><div class="preview-title">دارایی‌ها و جهت بصری بازی</div></div>
    <div class="status-badge"><span class="status-dot"></span>تصمیم‌ها و محتوای اولیه آماده است</div>
  </div>
  <div class="preview-tabs" role="tablist" aria-label="بخش‌های پیش‌نمایش">
    <button class="preview-tab active" data-screen="title" role="tab" aria-selected="true">صفحهٔ شروع</button>
    <button class="preview-tab" data-screen="garden" role="tab" aria-selected="false">محیط نمونهٔ باغ</button>
    <button class="preview-tab" data-screen="gallery" role="tab" aria-selected="false">شخصیت‌ها و گیاهان</button>
  </div>

  <section id="screen-title" class="screen active" role="tabpanel" aria-label="صفحه شروع">
    <div class="title-frame">
      <img class="title-bg" src="__TITLE__" alt="تصویر اصلی بازی؛ نوجوان داوطلب مقابل باغ ایرانی و شهر در غروب">
      <div class="title-shade"></div>
      <div class="title-content">
        <img class="logo-mark" src="__LOGO__" alt="نشان ریشه‌های ایثار">
        <h1 class="game-name">ریشه‌های ایثار</h1>
        <p class="game-sub">کاشت یک نهال، زنده نگه داشتن یک خاطره؛ مراقبت از طبیعت، ساختن آیندهٔ شهر.</p>
        <div class="menu-stack">
          <button class="game-btn primary" id="preview-start">شروع بازی</button>
          <div class="menu-row"><button class="game-btn" data-toast="تنظیمات صدا، موسیقی و کنترل‌ها در نسخهٔ نهایی قابل تغییر خواهند بود.">تنظیمات</button><button class="game-btn" data-toast="بازی دربارهٔ همکاری نوجوانان برای احیای باغ یادبود و حفاظت از محیط زیست است.">دربارهٔ بازی</button></div>
        </div>
      </div>
      <div class="version-tag">نسخهٔ پیش‌توسعه · موتور Godot</div>
    </div>
  </section>

  <section id="screen-garden" class="screen" role="tabpanel" aria-label="محیط نمونه باغ">
    <div class="garden-shell">
      <div class="hud">
        <div class="hud-group"><span class="hud-pill"><span class="hud-dot"></span>محیط زیست ۳۵</span><span class="hud-pill"><span class="hud-dot heart"></span>مسئولیت ۱۸</span><span class="hud-pill"><span class="hud-dot book"></span>آگاهی ۱۲</span><span class="hud-pill"><span class="hud-dot star"></span>۱۵۰</span></div>
        <div class="hud-group"><span class="hud-pill">آب ۳</span><span class="hud-pill">نهال ۳</span><span class="hud-pill">کود ۱</span></div>
      </div>
      <div class="garden-stage">
        <div id="garden-grid" class="garden-grid" aria-hidden="true"></div>
        <div class="world-sprite sprite-cypress" style="left:24%;top:23%"></div>
        <div class="world-sprite sprite-arghavan" style="left:41%;top:28%"></div>
        <div class="world-sprite sprite-guide" style="left:45%;top:60%"></div>
        <div class="world-sprite sprite-player" style="left:54%;top:63%"></div>
        <div class="quest-card"><div class="quest-eyebrow">فصل ۲ · نخستین نهال</div><div class="quest-title">زمین را آماده کن و نهالی امید بکار</div><div class="quest-line">آماده‌سازی زمین ۲ از ۳ · آبیاری ۱ از ۲</div><div class="quest-progress"><span></span></div></div>
        <div class="dialogue-card"><div class="speaker">راهنمای محیط زیست · استاد رهنما</div><div class="dialogue-text">«هر نهال با یک تصمیم کوچک آغاز می‌شود. اول خاک را بشناس، بعد با آرامش و بدون هدررفت آب، کاشت را شروع کن.»</div></div>
        <div class="joystick" aria-hidden="true"></div>
        <div class="action-cluster"><button class="action-round" data-toast="دکمهٔ تعامل در نسخهٔ بازی با نزدیک‌شدن به نهال و شخصیت‌ها فعال می‌شود."">تعامل</button><button class="action-round water" data-toast="آبیاری در سیستم واقعی بازی روی رطوبت خاک و نیاز گیاه اثر می‌گذارد.">آبیاری</button></div>
      </div>
    </div>
  </section>

  <section id="screen-gallery" class="screen" role="tabpanel" aria-label="گالری دارایی‌ها">
    <div class="gallery-grid">
      <div class="asset-card"><div class="asset-window"><div class="asset-sprite" style="background-image:url('__PLAYER__');background-size:400% 600%;background-position:0% 0%"></div></div><div class="asset-name">آرمان · قهرمان بازی</div><div class="asset-note">انیمیشن راه‌رفتن، کاشت و آبیاری</div></div>
      <div class="asset-card"><div class="asset-window"><div class="asset-sprite" style="background-image:url('__NPCS__');background-size:600% 400%;background-position:0% 0%"></div></div><div class="asset-name">استاد رهنما</div><div class="asset-note">راهنمای محیط زیست باغ</div></div>
      <div class="asset-card"><div class="asset-window"><div class="asset-sprite" style="background-image:url('__NPCS__');background-size:600% 400%;background-position:20% 33.333%"></div></div><div class="asset-name">خانم نگار</div><div class="asset-note">مربی فرهنگی و روایت‌گو</div></div>
      <div class="asset-card"><div class="asset-window"><div class="asset-sprite" style="background-image:url('__PLANTS__');background-size:800% 600%;background-position:57.142% 0%"></div></div><div class="asset-name">سرو · گونهٔ بومی</div><div class="asset-note">شش مرحلهٔ رشد از بذر تا درخت</div></div>
      <div class="asset-card"><div class="asset-window"><div class="asset-sprite" style="background-image:url('__PLANTS__');background-size:800% 600%;background-position:57.142% 40%"></div></div><div class="asset-name">انار</div><div class="asset-note">مدیریت آب، خاک و سلامت گیاه</div></div>
      <div class="asset-card"><div class="asset-window"><div class="asset-sprite" style="background-image:url('__PLANTS__');background-size:800% 600%;background-position:57.142% 60%"></div></div><div class="asset-name">ارغوان · درخت بومی</div><div class="asset-note">شاخه‌های زینتی و رشد مرحله‌ای</div></div>
      <div class="asset-card"><div class="asset-window"><div class="asset-sprite" style="background-image:url('__PROPS__');background-size:800% 400%;background-position:0% 0%"></div></div><div class="asset-name">ابزارهای باغ</div><div class="asset-note">آب‌پاش، بیل، دستکش و پلاک یادبود</div></div>
      <div class="asset-card"><div class="asset-window"><div class="asset-sprite" style="background-image:url('__PROPS__');background-size:800% 400%;background-position:42.857% 66.666%"></div></div><div class="asset-name">فضای ایرانی</div><div class="asset-note">حوض، نیمکت‌ها و عناصر کاشی‌پردازی</div></div>
    </div>
    <div class="scope-strip"><div class="scope-item"><div class="scope-num">۸</div><div class="scope-label">فصل داستانی</div></div><div class="scope-item"><div class="scope-num">۳۰</div><div class="scope-label">مأموریت متصل</div></div><div class="scope-item"><div class="scope-num">۱۶</div><div class="scope-label">پرسش با بازخورد</div></div><div class="scope-item"><div class="scope-num">۶</div><div class="scope-label">درخت بومی</div></div></div>
  </section>
  <div class="preview-note"><span class="note-mark"></span><span>این نما، ظاهر و دارایی‌های آماده را نشان می‌دهد. حرکت بازیکن، رشد واقعی نهال‌ها، مأموریت‌ها و APK هنوز در حال پیاده‌سازی هستند.</span></div>
  <div id="preview-toast" class="toast" role="status" aria-live="polite"></div>
</div>`;

// Substitute embedded assets while leaving the preview markup and layout intact.
let output = html;
const replacements = {
  FONT_REGULAR: assets.fontRegular,
  FONT_BOLD: assets.fontBold,
  TITLE: assets.title,
  LOGO: assets.logo,
  TILES: assets.tiles,
  PLAYER: assets.player,
  NPCS: assets.npcs,
  PLANTS: assets.plants,
  PROPS: assets.props,
};
for (const [key, value] of Object.entries(replacements)) output = output.replaceAll(`__${key}__`, value);

// Append browser-only tab switching, toast messages, and garden-grid construction.
output += String.raw`<script>
(() => {
  const root = document.getElementById('roots-preview');
  const tabs = Array.from(root.querySelectorAll('.preview-tab'));
  const screens = Array.from(root.querySelectorAll('.screen'));
  const toast = root.querySelector('#preview-toast');
  let toastTimer;
  const showToast = (message) => {
    toast.textContent = message;
    toast.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove('show'), 3200);
  };
  const showScreen = (name) => {
    tabs.forEach((tab) => {
      const active = tab.dataset.screen === name;
      tab.classList.toggle('active', active);
      tab.setAttribute('aria-selected', String(active));
    });
    screens.forEach((screen) => screen.classList.toggle('active', screen.id === 'screen-' + name));
  };
  tabs.forEach((tab) => tab.addEventListener('click', () => showScreen(tab.dataset.screen)));
  root.querySelector('#preview-start').addEventListener('click', () => showScreen('garden'));
  root.querySelectorAll('[data-toast]').forEach((button) => button.addEventListener('click', () => showToast(button.dataset.toast)));

  const grid = root.querySelector('#garden-grid');
  const sheetCols = 8;
  const sheetRows = 4;
  for (let y = 0; y < 9; y++) {
    for (let x = 0; x < 16; x++) {
      let index = (x * 7 + y * 11) % 3;
      if (x >= 11 && y <= 3) index = (x + y) % 2 ? 6 : 29;
      if (x === 10 && y <= 3) index = 16;
      if (y === 6 || x === 8) index = 3;
      if (y === 0 || x === 0 || x === 15) index = 18;
      if (y === 8) index = 7;
      if (x >= 2 && x <= 6 && y >= 2 && y <= 4) index = (x + y) % 3 ? 10 : 4;
      if ((x === 3 || x === 5) && y === 3) index = 5;
      if ((x === 1 && y === 6) || (x === 13 && y === 6) || (x === 14 && y === 6) || (x === 11 && y === 5)) index = ({1:20,13:13,14:14,11:23})[x];
      if ((x === 9 && y === 7) || (x === 4 && y === 5)) index = 21;
      if ((x * 13 + y * 17) % 47 === 0 && y > 0 && y < 6 && x > 0 && x < 11) index = 8 + ((x + y) % 2);
      const col = index % sheetCols;
      const row = Math.floor(index / sheetCols);
      const tile = document.createElement('div');
      tile.className = 'tile';
      tile.style.backgroundPosition = ((col / (sheetCols - 1)) * 100) + '% ' + ((row / (sheetRows - 1)) * 100) + '%';
      grid.appendChild(tile);
    }
  }
})();
</script>`;

// Write the standalone preview to the session visualization directory.
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(outFile, output);
console.log(outFile);
console.log(`${Buffer.byteLength(output)} bytes`);
