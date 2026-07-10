extends PanelContainer
# Ambient "Swamp Times" headline strip under the top HUD bar. Throttled: one
# headline every ~45s, faded in and out, so the satire surfaces during long
# drain stretches without the distraction of a constant crawl (the always-on
# scroll version was cut for exactly that reason). Lines are picked by total
# drain progress so the headlines escalate as you drain; a prestige pool joins
# the mix once you've sold out at least once.

const HEADLINE_INTERVAL: float = 45.0
const FIRST_DELAY: float = 12.0
const HOLD_TIME: float = 7.0
const FADE_TIME: float = 0.8

var _label: Label
var _timer: float = HEADLINE_INTERVAL - FIRST_DELAY
var _showing: bool = false
var _last_line: String = ""

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
var _prestige: Array[String] = [
	"Officials report déjà vu as draining resumes. 'Not this guy again.'",
	"Northwind Analytics reports 'strong repeat engagement' in the wetlands sector.",
	"The swamp is back. The drainer is back. The Consultant invoiced both.",
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 13)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.72)
	add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color(0.85, 0.92, 0.8))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	modulate.a = 0.0

func _process(delta: float) -> void:
	if _showing:
		return
	_timer += delta
	if _timer >= HEADLINE_INTERVAL:
		_timer = 0.0
		_show_headline()

func _show_headline() -> void:
	_showing = true
	_label.text = "SWAMP TIMES — " + _pick_line()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	tw.tween_interval(HOLD_TIME)
	tw.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(func() -> void: _showing = false)

func _pick_line() -> String:
	var pct: float = GameManager.get_total_water_percent()
	var stage: Array[String]
	if pct > 90.0:
		stage = _intro
	elif pct > 60.0:
		stage = _early
	elif pct > 30.0:
		stage = _mid
	elif pct > 5.0:
		stage = _late
	else:
		stage = _endgame
	var stage_pool: Array[String] = stage.duplicate()
	if GameManager.prestige_count > 0:
		stage_pool.append_array(_prestige)
	# Weight toward stage lines so the escalation reads; generic fills the gaps.
	var pool: Array[String] = stage_pool if randf() < 0.7 else _generic
	var line: String = pool.pick_random()
	if line == _last_line and pool.size() > 1:
		line = pool.pick_random()
	_last_line = line
	return line
