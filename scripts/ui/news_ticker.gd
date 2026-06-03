extends PanelContainer
# Ambient "Swamp Times" news crawl — a thin scrolling strip under the top HUD bar.
# Non-interrupting: surfaces escalating satire during the long drain stretches
# (the funniest writing was previously buried in skippable caves). Lines are
# picked by total drain progress so the headlines escalate as you drain.

const SPEED: float = 32.0
const SEP: String = "        •        "  # bullet separator
const VISIBLE_LINES: int = 6

var _clip: Control
var _label: Label
var _scroll_x: float = 0.0
var _text_w: float = 0.0

var _generic: Array[String] = [
	"Field operations budget remaining: $500.",
	"The Consultant has submitted another invoice.",
	"Officials remind the public the water was always there.",
	"A government tanker was seen near the swamp doing nothing suspicious.",
	"Senator Swampsworth has still not visited the swamp.",
	"Experts agree the swamp is 'fine, actually.'",
	"Weather service forecasts a 100% chance of swamp.",
	"Sources confirm nothing, at great expense.",
]
var _intro: Array[String] = [
	"BREAKING: One man buys a spoon. Authorities unconcerned.",
	"City Hall: 'He'll lose interest, like the public usually does.'",
	"New hire requests a shovel; told it is 'on backorder.'",
]
var _early: Array[String] = [
	"He bought a BUCKET. With his OWN money.",
	"Officials form a committee to study the man studying the swamp.",
	"Drainer's approval rating now exceeds Congress's.",
]
var _mid: Array[String] = [
	"PANIC: Water levels measurably lower. Nobody authorized this.",
	"Lobby firm 'Kickback & Associates' denies everything preemptively.",
	"Mysterious crate found in mud, labeled PROPERTY OF NO ONE.",
]
var _late: Array[String] = [
	"Politicians announce the swamp was 'a wetland project all along.'",
	"Unmarked helicopter spotted. Officials: 'routine. very routine.'",
	"Leaked memo, one line: 'Do not let him reach the bottom.'",
]
var _endgame: Array[String] = [
	"The swamp is nearly gone. So are several officials' flight records.",
	"Press conference cancelled; podium found abandoned, still warm.",
	"It was always going to come back. You drained an ocean anyway.",
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 13)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.72)
	add_theme_stylebox_override("panel", style)

	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_clip)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color(0.85, 0.92, 0.8))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_label)

	_rebuild()

func _process(delta: float) -> void:
	if _text_w <= 0.0:
		_rebuild()
		return
	_scroll_x -= SPEED * delta
	_label.position.x = _scroll_x
	_label.position.y = (size.y - _label.get_minimum_size().y) * 0.5
	if _scroll_x < -_text_w:
		_rebuild()

func _rebuild() -> void:
	_label.text = _compose()
	_text_w = _label.get_minimum_size().x
	_scroll_x = maxf(size.x, 1.0)  # start just off the right edge
	_label.position.x = _scroll_x

func _compose() -> String:
	var pct: float = GameManager.get_total_water_percent()
	var pool: Array[String] = _generic.duplicate()
	if pct > 90.0:
		pool.append_array(_intro)
	elif pct > 60.0:
		pool.append_array(_early)
	elif pct > 30.0:
		pool.append_array(_mid)
	elif pct > 5.0:
		pool.append_array(_late)
	else:
		pool.append_array(_endgame)
	pool.shuffle()
	var pick: Array[String] = pool.slice(0, mini(VISIBLE_LINES, pool.size()))
	return "SWAMP TIMES" + SEP + SEP.join(pick) + SEP
