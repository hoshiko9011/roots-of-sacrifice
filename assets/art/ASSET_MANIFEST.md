# Roots of Sacrifice Art Asset Manifest

The game artwork is original to Roots of Sacrifice (ریشه‌های ایثار). Most SVG assets are procedurally generated; the sprout icon sources under `assets/art/source` and `assets/art/cinematic_garden.png` were created and supplied by the project owner and are used with authorization. No other third-party artwork is incorporated. SVG geometry is deterministic; no external fonts, images, scripts, or network resources are required at runtime.

## Generated SVG assets

| File | Dimensions | Grid and contents |
| --- | ---: | --- |
| `assets/art/tiles.svg` | 512 × 256 | 8 × 4 atlas; 32 named 64 × 64 terrain/object tiles in the requested order |
| `assets/art/player.svg` | 256 × 384 | 4 × 6 sheet; 24 directional, walking, watering, and planting frames |
| `assets/art/npcs.svg` | 384 × 256 | 4 × 6 sheet; 24 guide, mentor, student, and volunteer poses |
| `assets/art/plants.svg` | 512 × 384 | 6 × 6 used cells in an 8 × 6 atlas; six stages for each of six native Iranian tree species, two transparent spare columns |
| `assets/art/props.svg` | 512 × 256 | 8 × 4 atlas; 32 tools, collectibles, environment props, and effects |
| `assets/art/icons.svg` | 512 × 128 | 16 × 4 atlas; 33 defined 32-pixel game icons and 31 transparent spare cells |
| `assets/art/sprout_icon.svg` | 64 × 64 | User-created growth sprout icon converted losslessly to crisp SVG pixel runs |
| `assets/art/logo.svg` | 640 × 256 | Transparent centered tree/heart-root logo mark |
| `assets/art/weather_overlay.svg` | 512 × 512 | Transparent edge-weighted light-rain overlay with a clear center |
| `assets/art/android_icon.svg` | 512 × 512 | User-created primary sprout icon converted losslessly to crisp SVG pixel runs |
| `assets/art/android_icon_foreground.svg` | 432 × 432 | Transparent two-leaf sprout and soil foreground matching the user icon |
| `assets/art/android_icon_background.svg` | 432 × 432 | Warm ember, gold halo and earth adaptive-icon background |
| `assets/art/android_icon_monochrome.svg` | 432 × 432 | Transparent sprout, root and soil silhouette for themed Android launcher icons |
| `assets/art/scene_garden_overgrown.svg` | 1280 × 720 | Overgrown forgotten garden with a shed, pond and six reserved planting beds |
| `assets/art/scene_garden_saplings.svg` | 1280 × 720 | Renewed garden with repaired fences, young trees and six reserved planting beds |
| `assets/art/scene_garden_soil_water.svg` | 1280 × 720 | Soil and water chapter garden with compost area, drainage and six reserved planting beds |
| `assets/art/scene_school_courtyard.svg` | 1280 × 720 | School courtyard with classrooms, paths, water tank and six reserved planting beds |
| `assets/art/scene_memorial_garden.svg` | 1280 × 720 | Quiet memorial garden with cypress trees, monument, reflecting pool and six reserved planting beds |
| `assets/art/scene_neighborhood_park.svg` | 1280 × 720 | Neighborhood park with benches, trees, pond and six reserved planting beds |
| `assets/art/scene_green_city.svg` | 1280 × 720 | Green city street with buildings, canal, street trees and six reserved planting beds |
| `assets/art/scene_city_stewardship.svg` | 1280 × 720 | City stewardship celebration with bunting, mature trees, canal and six reserved planting beds |
| `assets/art/button_start.svg` | 360 × 84 | Leaf-framed green primary button; matching `_hover` and `_pressed` variants |
| `assets/art/button_wood.svg` | 360 × 76 | Leaf-framed wooden menu button; matching `_hover` and `_pressed` variants |
| `assets/art/button_wood_dark.svg` | 360 × 76 | Leaf-framed dark wooden exit button; matching `_hover` and `_pressed` variants |
| `assets/art/button_settings.svg` | 160 × 58 | Compact leaf-framed wooden settings button; matching `_hover` and `_pressed` variants |
| `assets/art/button_about.svg` | 240 × 66 | Compact leaf-framed wooden about-team button; matching `_hover` and `_pressed` variants |
| `assets/art/button_hud.svg` | 132 × 58 | Compact leaf-framed wooden map/pause button; matching `_hover` and `_pressed` variants |
| `assets/art/button_quest.svg` | 360 × 66 | Leaf-framed green mission tracker button; matching `_hover` and `_pressed` variants |
| `assets/art/button_compact.svg` | 160 × 64 | Leaf-framed wooden memorial/plants/achievement button; matching `_hover` and `_pressed` variants |
| `assets/art/button_water.svg` | 360 × 84 | Leaf-framed blue water/action button; matching `_hover` and `_pressed` variants |
| `assets/art/button_danger.svg` | 360 × 84 | Leaf-framed red danger button; matching `_hover` and `_pressed` variants |
| `assets/art/hud_panel.svg` | 850 × 64 | Wooden resource HUD frame with gold border and leaf details |
| `assets/art/hud_chip.svg` | 92 × 44 | Green resource chip for scores, heart, water, seeds, compost and clock |
| `assets/art/title_panel.svg` | 840 × 184 | Forest-green title banner with wooden frame, gold trim, sprout-and-roots medallion and leaf corners |
| `assets/art/about_panel.svg` | 900 × 650 | Dedicated pixel-art team panel with wooden frame, cream paper, sprout emblem, green leaves and small blossoms |
| `assets/art/ASSET_MANIFEST.md` | — | This inventory and regeneration guide |

## User-supplied source art

- `assets/art/source/user_sprout_primary.png` — 256 × 256 RGBA icon created by the project owner; source for the legacy launcher icon.
- `assets/art/source/user_sprout_growth.png` — 64 × 64 RGBA icon created by the project owner; source for the in-game sprout icon and icon-atlas cell.
- `assets/art/cinematic_garden.png` — 1792 × 1024 RGBA scene created by the project owner; source for the animated title and ending background.

The icon sources are preserved unchanged, excluded from Android exports, and converted to deterministic SVG pixel geometry by the generator. The cinematic source is preserved unchanged and animated at runtime by `cinematic_garden.gdshader`.

## Existing protected asset

`assets/art/title_art.png` already exists and is intentionally not generated or overwritten. The generator verifies that its checksum remains unchanged.

## Regeneration

From the project root:

```sh
node tools/generate_art.mjs
```

The command rewrites only the generated SVG files and this manifest, then validates XML structure, dimensions, palette usage, cell coverage, chapter-scene count, reserved planting-court metadata, and file existence. In Godot, keep SVG import filtering set to nearest so the chunky pixels remain crisp when scaled.
