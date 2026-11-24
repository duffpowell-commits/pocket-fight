extends RefCounted
## A monster design: plain data, no drawing. The creator edits one of these, the save file stores
## it, MonsterView draws it. Looks and gameplay are separate fields: nothing in LOOKS or SHAPE
## changes a fight (docs/PITCH.md pillar 2).
##
##   Monster.fresh()            a valid default design
##   Monster.clean(d)           any saved/typed dictionary -> a valid design (bad values fall back)
##   Monster.surprise(rng)      a random valid design
##   Monster.from_text(s, base) "a fat blue cat with horns" -> {design, heard, missed}

## Pick-one parts. First entry is the default. Order = the order of the tabs in the creator.
const PARTS := {
	"body": ["Round", "Leggy", "Bean", "Slink"],
	"ears": ["Pointy", "Round", "Floppy", "Long", "Fins", "None"],
	"eyes": ["Big", "Dot", "Sleepy", "Fierce", "Cyclops"],
	"mouth": ["Smile", "Fangs", "Beak", "Tongue"],
	"tail": ["Paddle", "Whip", "Puff", "Club", "None"],
	"marks": ["None", "Spots", "Stripes", "Belly", "Mask"],
	"top": ["None", "Horns", "Antenna", "Mane"],
	"back": ["None", "Spikes", "Wings"],
	"color": ["Rust", "Lake", "Moss", "Sun", "Plum", "Snow", "Coal", "Rose", "Mint", "Ember"],
	"accent": ["Snow", "Coal", "Sun", "Rust", "Lake", "Moss", "Plum", "Rose", "Mint", "Ember"],
	"move": ["Splash", "Climb"],
	"mood": ["Bold", "Shy", "Goofy", "Grumpy"],
}
## Sliders, each 0..1, default 0.5.
const SHAPE := ["size", "chub", "legs", "head"]
## What the creator calls each field.
const TITLES := {
	"body": "BODY", "ears": "EARS", "eyes": "EYES", "mouth": "MOUTH", "tail": "TAIL",
	"marks": "MARKS", "top": "TOP", "back": "BACK", "color": "COLOR", "accent": "2ND COLOR",
	"move": "MOVE", "mood": "MOOD", "size": "SIZE", "chub": "CHUB", "legs": "LEGS", "head": "HEAD",
}
const COLORS := {
	"Rust": Color("d9774f"), "Lake": Color("4fa8cf"), "Moss": Color("86b455"), "Sun": Color("f0c24a"),
	"Plum": Color("9a6fd0"), "Snow": Color("f1ece0"), "Coal": Color("4a4f5c"), "Rose": Color("e98aa6"),
	"Mint": Color("6fd0b4"), "Ember": Color("e2533f"),
}
const NAME_MAX := 14
const NAMES := ["Biscuit", "Mudge", "Pip", "Gravy", "Noodle", "Tuck", "Bramble", "Soot", "Wobble",
	"Fennel", "Clove", "Dumpling", "Moss", "Pickle", "Rumble", "Skillet", "Tater", "Zest"]


static func fresh() -> Dictionary:
	var d := {"name": "Biscuit"}
	for k in PARTS:
		d[k] = PARTS[k][0]
	for k in SHAPE:
		d[k] = 0.5
	return d


## Whatever comes in (an old save, a typed draft, garbage), a complete valid design comes out.
static func clean(src: Variant) -> Dictionary:
	var d := fresh()
	if typeof(src) != TYPE_DICTIONARY:
		return d
	for k in PARTS:
		if src.get(k) in PARTS[k]:
			d[k] = src[k]
	for k in SHAPE:
		var v: Variant = src.get(k)
		if typeof(v) in [TYPE_FLOAT, TYPE_INT]:
			d[k] = clampf(float(v), 0.0, 1.0)
	d["name"] = clean_name(src.get("name", d["name"]))
	if d["accent"] == d["color"]:      # markings in the body colour would be invisible
		d["accent"] = "Coal" if d["color"] == "Snow" else "Snow"
	return d


static func clean_name(v: Variant) -> String:
	var s := str(v).strip_edges().replace("\n", " ")
	s = s.substr(0, NAME_MAX).strip_edges()
	return s if s != "" else "Biscuit"


static func surprise(rng: RandomNumberGenerator) -> Dictionary:
	var d := {}
	for k in PARTS:
		d[k] = PARTS[k][rng.randi() % PARTS[k].size()]
	for k in SHAPE:
		d[k] = snappedf(rng.randf(), 0.05)
	d["name"] = NAMES[rng.randi() % NAMES.size()]
	return clean(d)


# ---------------------------------------------------------------- describe it

## Word -> the fields it sets. Checked as whole words, after lower-casing. Longer phrases
## (PHRASES) are found first and removed, then applied last, so "cat with no tail" has no tail.
const WORDS := {
	# colours: the first colour word is the body, the second the markings
	"red": {"_color": "Ember"}, "ember": {"_color": "Ember"}, "crimson": {"_color": "Ember"},
	"orange": {"_color": "Rust"}, "rust": {"_color": "Rust"}, "brown": {"_color": "Rust"}, "ginger": {"_color": "Rust"},
	"blue": {"_color": "Lake"}, "lake": {"_color": "Lake"},
	"green": {"_color": "Moss"}, "moss": {"_color": "Moss"}, "mossy": {"_color": "Moss"},
	"yellow": {"_color": "Sun"}, "gold": {"_color": "Sun"}, "golden": {"_color": "Sun"}, "sun": {"_color": "Sun"},
	"purple": {"_color": "Plum"}, "plum": {"_color": "Plum"}, "violet": {"_color": "Plum"},
	"white": {"_color": "Snow"}, "snow": {"_color": "Snow"}, "cream": {"_color": "Snow"}, "pale": {"_color": "Snow"},
	"black": {"_color": "Coal"}, "coal": {"_color": "Coal"}, "dark": {"_color": "Coal"}, "grey": {"_color": "Coal"}, "gray": {"_color": "Coal"},
	"pink": {"_color": "Rose"}, "rose": {"_color": "Rose"},
	"teal": {"_color": "Mint"}, "mint": {"_color": "Mint"}, "aqua": {"_color": "Mint"},
	# animals: a starting kit of parts
	"cat": {"ears": "Pointy", "tail": "Whip", "body": "Round"}, "kitten": {"ears": "Pointy", "tail": "Whip", "size": 0.2},
	"fox": {"ears": "Pointy", "tail": "Puff", "body": "Leggy", "_color": "Rust"},
	"dog": {"ears": "Floppy", "tail": "Whip", "mouth": "Tongue"}, "puppy": {"ears": "Floppy", "mouth": "Tongue", "size": 0.2},
	"wolf": {"ears": "Pointy", "tail": "Puff", "mouth": "Fangs", "body": "Leggy"},
	"bunny": {"ears": "Long", "tail": "Puff"}, "rabbit": {"ears": "Long", "tail": "Puff"},
	"bear": {"ears": "Round", "tail": "None", "chub": 0.85, "size": 0.8},
	"mouse": {"ears": "Round", "tail": "Whip", "size": 0.15}, "rat": {"ears": "Round", "tail": "Whip", "mouth": "Fangs"},
	"frog": {"ears": "None", "tail": "None", "eyes": "Big", "body": "Round", "legs": 0.2, "_color": "Moss"},
	"toad": {"ears": "None", "tail": "None", "body": "Round", "marks": "Spots", "chub": 0.8},
	"bird": {"mouth": "Beak", "back": "Wings", "ears": "None", "body": "Bean"},
	"owl": {"mouth": "Beak", "back": "Wings", "eyes": "Big", "ears": "Pointy", "body": "Bean"},
	"duck": {"mouth": "Beak", "back": "Wings", "ears": "None", "tail": "Paddle"},
	"chicken": {"mouth": "Beak", "back": "Wings", "ears": "None", "body": "Round"},
	"dragon": {"top": "Horns", "back": "Wings", "mouth": "Fangs", "tail": "Club", "body": "Bean"},
	"dino": {"back": "Spikes", "tail": "Club", "ears": "None", "mouth": "Fangs", "body": "Bean"},
	"dinosaur": {"back": "Spikes", "tail": "Club", "ears": "None", "mouth": "Fangs", "body": "Bean"},
	"lizard": {"body": "Slink", "ears": "None", "tail": "Whip"}, "gecko": {"body": "Slink", "ears": "None", "tail": "Whip", "eyes": "Big"},
	"snake": {"body": "Slink", "ears": "None", "tail": "Whip", "mouth": "Fangs", "legs": 0.0},
	"weasel": {"body": "Slink", "ears": "Round", "tail": "Puff"}, "otter": {"body": "Slink", "ears": "Round", "tail": "Paddle"},
	"ferret": {"body": "Slink", "ears": "Round", "tail": "Puff", "marks": "Mask"},
	"fish": {"ears": "Fins", "tail": "Paddle", "legs": 0.0}, "shark": {"ears": "Fins", "tail": "Paddle", "mouth": "Fangs", "back": "Spikes"},
	"beaver": {"tail": "Paddle", "ears": "Round", "mouth": "Fangs", "chub": 0.75},
	"raccoon": {"marks": "Mask", "tail": "Puff", "ears": "Pointy"}, "panda": {"marks": "Mask", "ears": "Round", "chub": 0.85, "_color": "Snow"},
	"tiger": {"marks": "Stripes", "ears": "Round", "tail": "Whip", "mouth": "Fangs", "_color": "Rust"},
	"zebra": {"marks": "Stripes", "top": "Mane", "body": "Leggy", "_color": "Snow"},
	"lion": {"top": "Mane", "tail": "Whip", "ears": "Round", "_color": "Sun"},
	"horse": {"top": "Mane", "body": "Leggy", "tail": "Whip", "ears": "Pointy"},
	"deer": {"top": "Horns", "body": "Leggy", "tail": "Puff", "marks": "Spots"}, "goat": {"top": "Horns", "body": "Leggy", "tail": "Puff"},
	"cow": {"top": "Horns", "marks": "Spots", "tail": "Whip", "chub": 0.7}, "bull": {"top": "Horns", "eyes": "Fierce", "chub": 0.7},
	"pig": {"ears": "Floppy", "tail": "Whip", "chub": 0.85, "_color": "Rose"},
	"bug": {"top": "Antenna", "ears": "None", "eyes": "Big"}, "beetle": {"top": "Horns", "ears": "None", "body": "Round"},
	"moth": {"top": "Antenna", "ears": "None"}, "ant": {"top": "Antenna", "ears": "None", "size": 0.1},
	"bat": {"back": "Wings", "ears": "Pointy", "mouth": "Fangs", "tail": "None"},
	"hedgehog": {"back": "Spikes", "body": "Round", "tail": "None", "ears": "Round"},
	"cyclops": {"eyes": "Cyclops"},
	# parts by name
	"horns": {"top": "Horns"}, "horned": {"top": "Horns"}, "antlers": {"top": "Horns"},
	"fins": {"ears": "Fins"}, "finned": {"ears": "Fins"},
	"wings": {"back": "Wings"}, "winged": {"back": "Wings"}, "flying": {"back": "Wings"},
	"spikes": {"back": "Spikes"}, "spiky": {"back": "Spikes"}, "spiked": {"back": "Spikes"}, "spines": {"back": "Spikes"},
	"antenna": {"top": "Antenna"}, "antennae": {"top": "Antenna"},
	"mane": {"top": "Mane"}, "maned": {"top": "Mane"}, "mohawk": {"top": "Mane"},
	"fangs": {"mouth": "Fangs"}, "fanged": {"mouth": "Fangs"}, "teeth": {"mouth": "Fangs"}, "toothy": {"mouth": "Fangs"},
	"beak": {"mouth": "Beak"}, "beaked": {"mouth": "Beak"},
	"tongue": {"mouth": "Tongue"}, "smile": {"mouth": "Smile"}, "smiling": {"mouth": "Smile"}, "smiley": {"mouth": "Smile"},
	"spots": {"marks": "Spots"}, "spotted": {"marks": "Spots"}, "spotty": {"marks": "Spots"}, "freckles": {"marks": "Spots"},
	"stripes": {"marks": "Stripes"}, "striped": {"marks": "Stripes"}, "stripy": {"marks": "Stripes"},
	"belly": {"marks": "Belly"}, "mask": {"marks": "Mask"}, "masked": {"marks": "Mask"},
	"club": {"tail": "Club"}, "fluffy": {"tail": "Puff"}, "puffy": {"tail": "Puff"}, "paddle": {"tail": "Paddle"},
	"floppy": {"ears": "Floppy"}, "pointy": {"ears": "Pointy"},
	# shape
	"fat": {"chub": 1.0}, "chubby": {"chub": 0.9}, "chonky": {"chub": 1.0}, "chunky": {"chub": 0.9},
	"round": {"chub": 0.85, "body": "Round"}, "plump": {"chub": 0.85},
	"skinny": {"chub": 0.0}, "thin": {"chub": 0.1}, "slim": {"chub": 0.15}, "lanky": {"chub": 0.1, "legs": 0.9},
	"tiny": {"size": 0.0}, "small": {"size": 0.2}, "little": {"size": 0.2}, "baby": {"size": 0.1, "head": 0.9},
	"big": {"size": 0.85}, "huge": {"size": 1.0}, "giant": {"size": 1.0}, "large": {"size": 0.85},
	"tall": {"legs": 0.9}, "leggy": {"legs": 1.0, "body": "Leggy"}, "stubby": {"legs": 0.1}, "short": {"legs": 0.15},
	"long": {"body": "Slink"}, "bigheaded": {"head": 1.0},
	# mood
	"angry": {"eyes": "Fierce", "mood": "Grumpy"}, "grumpy": {"eyes": "Fierce", "mood": "Grumpy"},
	"mean": {"eyes": "Fierce", "mood": "Grumpy"}, "fierce": {"eyes": "Fierce", "mood": "Bold"},
	"scary": {"eyes": "Fierce", "mouth": "Fangs", "mood": "Bold"}, "brave": {"mood": "Bold"}, "bold": {"mood": "Bold"},
	"sleepy": {"eyes": "Sleepy", "mood": "Shy"}, "tired": {"eyes": "Sleepy"}, "lazy": {"eyes": "Sleepy"},
	"shy": {"mood": "Shy"}, "timid": {"mood": "Shy"}, "nervous": {"mood": "Shy"},
	"goofy": {"mood": "Goofy", "mouth": "Tongue"}, "silly": {"mood": "Goofy", "mouth": "Tongue"},
	"derpy": {"mood": "Goofy", "mouth": "Tongue", "eyes": "Dot"}, "happy": {"mouth": "Smile", "mood": "Goofy"},
	"cute": {"eyes": "Big", "head": 0.8}, "beady": {"eyes": "Dot"},
	# moves
	"splash": {"move": "Splash"}, "swims": {"move": "Splash"}, "swimmer": {"move": "Splash"}, "water": {"move": "Splash"},
	"climb": {"move": "Climb"}, "climbs": {"move": "Climb"}, "climber": {"move": "Climb"}, "climbing": {"move": "Climb"},
}
## Multi-word phrases, matched before single words. "no X" turns a part off.
const PHRASES := {
	"no tail": {"tail": "None"}, "without a tail": {"tail": "None"}, "tailless": {"tail": "None"},
	"no ears": {"ears": "None"}, "earless": {"ears": "None"},
	"no wings": {"back": "None"}, "no spikes": {"back": "None"}, "no horns": {"top": "None"},
	"no spots": {"marks": "None"}, "no stripes": {"marks": "None"}, "no marks": {"marks": "None"}, "plain": {"marks": "None"},
	"one eye": {"eyes": "Cyclops"}, "one eyed": {"eyes": "Cyclops"}, "one-eyed": {"eyes": "Cyclops"},
	"big eyes": {"eyes": "Big"}, "big head": {"head": 1.0}, "small head": {"head": 0.1}, "tiny head": {"head": 0.0},
	"long legs": {"legs": 1.0, "body": "Leggy"}, "short legs": {"legs": 0.1}, "no legs": {"legs": 0.0},
	"long ears": {"ears": "Long"}, "floppy ears": {"ears": "Floppy"}, "round ears": {"ears": "Round"},
	"pointy ears": {"ears": "Pointy"}, "long tail": {"tail": "Whip"}, "fluffy tail": {"tail": "Puff"},
	"spiky tail": {"tail": "Club"}, "club tail": {"tail": "Club"}, "flat tail": {"tail": "Paddle"},
}
## Words that carry no design meaning: never reported as "didn't catch".
const FILLER := ["a", "an", "the", "and", "with", "of", "that", "has", "have", "is", "its", "it", "in", "on",
	"very", "really", "kind", "sort", "like", "looks", "looking", "who", "my", "me", "i", "want", "make",
	"but", "or", "for", "to", "some", "two", "tail", "ears", "eyes", "legs", "body", "head", "mouth",
	"monster", "creature", "thing", "guy", "boy", "girl", "pet", "starter", "named", "called", "name", "color", "colored"]


## Turn a typed description into a draft. Only the fields the text mentions change; everything
## else stays as it is in `base`, and every result is still editable by hand afterwards.
## Returns {"design": Dictionary, "heard": [words understood], "missed": [words not understood]}.
static func from_text(text: String, base: Dictionary = {}) -> Dictionary:
	var d := clean(base) if not base.is_empty() else fresh()
	var heard: Array[String] = []
	var missed: Array[String] = []
	var named := ""
	# "named Gus" / "called Gus": the next word, original casing.
	var rx := RegEx.create_from_string("(?i)\\b(?:named|called)\\s+([A-Za-z][A-Za-z'\\-]*)")
	var m := rx.search(text)
	if m != null:
		named = m.get_string(1)
		text = text.replace(m.get_string(0), " ")
	var s := " " + text.to_lower() + " "
	for ch in [",", ".", "!", "?", ";", ":", "\n", "\t", "\"", "(", ")"]:
		s = s.replace(ch, " ")
	var colours: Array[String] = []
	var said: Array = []          # phrases are more exact than single words, so they are applied last
	var phrases := PHRASES.keys()
	phrases.sort_custom(func(a, b): return a.length() > b.length())
	for p in phrases:
		if (" " + p + " ") in s:
			said.append(PHRASES[p])
			heard.append(p)
			s = s.replace(" " + p + " ", "  ")
	for w in s.split(" ", false):
		var key := w.trim_suffix("'s")
		if not WORDS.has(key) and key.ends_with("s") and WORDS.has(key.trim_suffix("s")):
			key = key.trim_suffix("s")
		if WORDS.has(key):
			_apply(d, WORDS[key], colours)
			heard.append(w)
		elif not (key in FILLER) and not missed.has(w):
			missed.append(w)
	for fields in said:
		_apply(d, fields, colours)
	if colours.size() > 0:
		d["color"] = colours[0]
	if colours.size() > 1:
		d["accent"] = colours[1]
	if named != "":
		d["name"] = named
	return {"design": clean(d), "heard": heard, "missed": missed}


## Typed colour words win over an animal's usual colour, so "blue fox" is blue.
static func _apply(d: Dictionary, fields: Dictionary, colours: Array[String]) -> void:
	for k in fields:
		if k == "_color":
			if fields.size() == 1:
				colours.append(fields[k])       # a colour word the player typed
			elif colours.is_empty():
				d["color"] = fields[k]          # an animal's default; a typed colour overrides it below
		else:
			d[k] = fields[k]
