class_name CardPalette
extends RefCounted
## Colour tokens per card class (and the muted / raised variants the card frame uses). Split out of CardView.

## Palette tokens per class. Empty id is neutral keepsake paper.
const PALETTES := {
	&"": {
		"label": "KEEPSAKE", "stock": Color("#D7D0BC"), "frame": Color("#526979"),
		"ink": Color("#171D28"), "window": Color("#171D28"), "banner": Color("#BBB7A8"),
		"banner_ink": Color("#171D28"), "accent": Color("#526979"), "glyph": Color("#D7D0BC"),
	},
	&"deserter": {
		"label": "DESERTER", "stock": Color("#29313A"), "frame": Color("#A66A50"),
		"ink": Color("#E8E1D0"), "window": Color("#171D28"), "banner": Color("#49545D"),
		"banner_ink": Color("#F0EBDD"), "accent": Color("#A66A50"), "glyph": Color("#171D28"),
	},
	&"thief": {
		"label": "THIEF", "stock": Color("#253D3D"), "frame": Color("#78A99B"),
		"ink": Color("#E8E1D0"), "window": Color("#171D28"), "banner": Color("#41615B"),
		"banner_ink": Color("#F0EBDD"), "accent": Color("#78A99B"), "glyph": Color("#171D28"),
	},
	&"medium": {
		"label": "MEDIUM", "stock": Color("#342F42"), "frame": Color("#9A89AD"),
		"ink": Color("#E8E1D0"), "window": Color("#171D28"), "banner": Color("#5C526B"),
		"banner_ink": Color("#F0EBDD"), "accent": Color("#9A89AD"), "glyph": Color("#171D28"),
	},
	# The Stray: dark cobalt blue. Placeholder colours until the class art is designed (docs/CLASSES_PLAN.md).
	&"stray": {
		"label": "STRAY", "stock": Color("#1F2A3E"), "frame": Color("#6D87B3"),
		"ink": Color("#E8E1D0"), "window": Color("#171D28"), "banner": Color("#3B4F78"),
		"banner_ink": Color("#F0EBDD"), "accent": Color("#6D87B3"), "glyph": Color("#171D28"),
	},
	# Status cards (Dread, Murmur: what enemies shuffle in): a sickly grey-green, so they read as junk.
	&"status": {
		"label": "STATUS", "stock": Color("#333D31"), "frame": Color("#6F8A5C"),
		"ink": Color("#C4CFB6"), "window": Color("#161C15"), "banner": Color("#4A5845"),
		"banner_ink": Color("#DCE5CF"), "accent": Color("#8FAA73"), "glyph": Color("#161C15"),
	},
}


## The class palette adjusted for muted / raised, built once per combination (not per redraw).
static var _derived_palettes: Dictionary = {}


static func get_palette(id: StringName, muted: bool, raised: bool) -> Dictionary:
	if not muted and not raised:
		return PALETTES[id]
	var key := "%s|%d" % [id, 1 if muted else 2]
	if not _derived_palettes.has(key):
		var p: Dictionary = PALETTES[id].duplicate()
		if muted:
			for k in ["stock", "frame", "banner", "window", "accent"]:
				p[k] = _mute(p[k])
		else:
			p["frame"] = (p["frame"] as Color).lightened(0.15)
		_derived_palettes[key] = p
	return _derived_palettes[key]


static func _mute(c: Color) -> Color:
	var g := c.get_luminance()
	return Color(g, g, g).lerp(c, 0.45) * Color(0.88, 0.88, 0.88, 1.0)
