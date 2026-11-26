class_name GameAtlas
extends RefCounted

# Resolve shared sprite sheets, atlas cells, and UI icons through one cached resource accessor.
# Cache loaded art so repeated UI and world requests reuse the same resources.
static var _textures: Dictionary = {}
# Icon keys map to cells in the shared icon sheet; the sprout uses its own asset.
const ICONS: Dictionary = {
	"leaf": Vector2i(0, 0), "heart": Vector2i(1, 0), "book": Vector2i(2, 0),
	"star": Vector2i(3, 0), "water": Vector2i(4, 0), "soil": Vector2i(5, 0),
	"sun": Vector2i(6, 0), "seed": Vector2i(7, 0), "settings": Vector2i(0, 1),
	"sound": Vector2i(1, 1), "music": Vector2i(2, 1), "pause": Vector2i(3, 1),
	"play": Vector2i(4, 1), "back": Vector2i(5, 1), "close": Vector2i(6, 1),
	"check": Vector2i(7, 1), "quest": Vector2i(0, 2), "map": Vector2i(1, 2),
	"memorial": Vector2i(2, 2), "achievement": Vector2i(3, 2), "lock": Vector2i(4, 2),
	"info": Vector2i(5, 2), "home": Vector2i(6, 2), "chapter": Vector2i(7, 2),
	"team": Vector2i(8, 2),
	"recycle": Vector2i(4, 3), "trash": Vector2i(5, 3), "trophy": Vector2i(6, 3),
	"sprout": Vector2i(7, 3)
}

# Loads an art asset once and returns the cached texture.
static func texture(file: String) -> Texture2D:
	if not _textures.has(file):
		_textures[file] = load("res://assets/art/" + file)
	return _textures[file]

# Creates a clipped atlas region for one square sprite cell.
static func cell(file: String, column: int, row: int, pixels: int = 64) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = texture(file)
	result.region = Rect2(column * pixels, row * pixels, pixels, pixels)
	result.filter_clip = true
	return result

# Resolves a UI icon, using the standalone sprout asset when requested.
static func icon(key: String) -> Texture2D:
	if key == "sprout":
		return texture("sprout_icon.svg")
	var pos: Vector2i = ICONS.get(key, Vector2i.ZERO)
	return cell("icons.svg", pos.x, pos.y, 32)

# Maps a species to its plant-sheet row and clamps the growth stage to valid cells.
static func plant(species: String, stage: int) -> Texture2D:
	var ids := ["cypress", "native_oak", "pomegranate", "arghavan", "olive", "willow"]
	var row := maxi(0, ids.find(species))
	return cell("plants.svg", clampi(stage, 0, 5), row)
