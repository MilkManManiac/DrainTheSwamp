extends Node

# --- State ---
var return_position: Vector2 = Vector2.ZERO
var return_scene_path: String = "res://scenes/main.tscn"
var is_transitioning: bool = false

# --- Visual nodes ---
var fade_layer: CanvasLayer = null
var fade_rect: ColorRect = null
var popup_layer: CanvasLayer = null
var cave_popup: PanelContainer = null
var popup_label: Label = null
var popup_close_btn: Button = null
var popup_timer: float = 0.0
var popup_auto_close: float = 0.0

# --- Newspaper popup ---
var newspaper_layer: CanvasLayer = null
var newspaper_overlay: ColorRect = null
var newspaper_panel: PanelContainer = null
var newspaper_date_label: Label = null
var newspaper_headline: Label = null
var newspaper_subhead: Label = null
var newspaper_body: Label = null
var newspaper_prompt: Label = null
var newspaper_paper_style: StyleBoxFlat = null
var newspaper_corner_fold: Polygon2D = null
var newspaper_coffee_stain: Polygon2D = null
var newspaper_photo_label: Label = null
var showing_newspaper: bool = false
var newspaper_ready_for_input: bool = false
var milestone_newspapers: Array = []
var endgame_newspaper_queue: Array = []
var endgame_active: bool = false

# --- Lore popup ---
var lore_layer: CanvasLayer = null
var showing_lore: bool = false

# --- Burner phone (Northwind Analytics) ---
# Texts queue up and wait for a clear screen (no newspaper/lore/transition), so a
# pool-completion text never fights the milestone newspaper for the same keypress.
var phone_queue: Array[String] = []
var phone_cooldown: float = 0.0

# One-shot NA handler texts, keyed by story beat. Each beat is gated by a
# persisted story flag ("na_text_<key>") so it fires once per save, ever —
# the handler doesn't reintroduce herself after prestige.
const NA_TEXTS: Dictionary = {
	"first_sell": [
		"First payment cleared. Not from them. From us.\n\nYou do good work. Do not thank me. Just keep draining. The water hides much.\n\n— a Friend"
	],
	"pond": [
		"The puddle, now the pond. The papers say nobody cares. Somebody cares. Somebody bought you this phone.\n\nKeep everything you find in the water. Especially the papers.\n\n— a Friend"
	],
	"first_lore": [
		"The document from the cave. Photograph it. Front and back. Good light, no shadow.\n\nA hobbyist asks. I am the hobbyist.\n\n— a Friend"
	],
	"bog": [
		"Excellent labors, com— friend. My friend.\n\nThe trucks that refill the water at night — we have photographed the drivers. For no reason. We photograph many things.\n\n— a Friend",
		"Also: the drop box at the west edge of town. It is ours. Check it when the flag is up.\n\nDo not wave back at the flag.\n\n— a Friend"
	],
	"lake": [
		"Funds are not a problem. Buy the bigger bucket. We believe in you like a mother believes in a strong ox.\n\n— a Friend",
		"A man in town asked about you today. We asked about him. He has stopped asking.\n\nDo not worry about this.\n\n— a Friend"
	],
	"lagoon": [
		"Enough pretense. The containers from the lagoon — Northwind Analytics requires their contents catalogued. You will be compensated. You are always compensated.\n\nNotice this.\n\n— NA",
		"Your government wants you in a cell. We want you employed.\n\nConsider which is the better retirement plan.\n\n— NA"
	],
	"bayou": [
		"Fourteen officials fled the country this week. Twelve flew with airlines we also own. Business is good.\n\nKeep draining.\n\n— NA"
	],
	"atlantic": [
		"The ocean is gone. There is a list at the bottom. There is an island past it.\n\nBring the List to the island. We will handle everything after. We are very good at handling.\n\n— NA"
	],
	"first_prestige": [
		"You sold out. Good. Sentiment is a luxury for people with pensions.\n\nThe swamp refills. The arrangement continues. It always continues.\n\n— NA"
	]
}

func _ready() -> void:
	# Fade overlay — layer 100, full-screen black, starts transparent
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)

	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.anchors_preset = Control.PRESET_FULL_RECT
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)

	# Popup layer — layer 90
	popup_layer = CanvasLayer.new()
	popup_layer.layer = 90
	add_child(popup_layer)
	_build_popup()
	_init_milestone_newspapers()
	_build_newspaper_overlay()

func _build_popup() -> void:
	cave_popup = PanelContainer.new()
	cave_popup.visible = false
	cave_popup.anchors_preset = Control.PRESET_CENTER_BOTTOM
	cave_popup.position = Vector2(160, 280)
	cave_popup.size = Vector2(320, 80)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.06, 0.92)
	style.border_color = Color(0.6, 0.5, 0.3, 0.8)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	cave_popup.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	cave_popup.add_child(vbox)

	popup_label = Label.new()
	popup_label.text = ""
	popup_label.add_theme_font_size_override("font_size", 12)
	popup_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	popup_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(popup_label)

	popup_close_btn = Button.new()
	popup_close_btn.text = "[Close]"
	popup_close_btn.add_theme_font_size_override("font_size", 10)
	popup_close_btn.flat = true
	popup_close_btn.pressed.connect(_close_popup)
	vbox.add_child(popup_close_btn)

	popup_layer.add_child(cave_popup)

	# Connect to GameManager signals
	GameManager.loot_collected.connect(_on_loot_collected)
	GameManager.swamp_completed.connect(_on_swamp_completed)

	# Burner-phone story triggers (Northwind Analytics)
	GameManager.water_sold.connect(func(_amount: float) -> void: _queue_na_text("first_sell"))
	GameManager.lore_read.connect(func(_cave_id: String, _lore_id: String) -> void: _queue_na_text("first_lore"))
	GameManager.prestige_performed.connect(func() -> void: _queue_na_text("first_prestige"))
	GameManager.swamp_completed.connect(_on_story_swamp_completed)

var _newspaper_elapsed: float = 0.0

func _process(delta: float) -> void:
	if popup_auto_close > 0.0:
		popup_timer += delta
		if popup_timer >= popup_auto_close:
			_close_popup()

	if Input.is_action_just_pressed("ui_cancel") and cave_popup.visible:
		_close_popup()

	# Newspaper prompt pulse
	if showing_newspaper and newspaper_prompt:
		_newspaper_elapsed += delta
		newspaper_prompt.modulate.a = 0.5 + 0.5 * sin(_newspaper_elapsed * 2.0)

	# Burner phone: deliver the next queued text once the screen is clear.
	# While anything story-modal is up, hold at 1s so the text lands a beat
	# after the other surface closes instead of the same frame.
	if phone_queue.size() > 0:
		if showing_lore or showing_newspaper or endgame_active or is_transitioning or ending_choice_layer != null:
			phone_cooldown = maxf(phone_cooldown, 1.0)
		elif phone_cooldown > 0.0:
			phone_cooldown -= delta
		else:
			var msg: String = phone_queue.pop_front()
			AudioManager.play("loot", 1.3, -6.0)
			show_document_popup(msg, "MESSAGE RECEIVED", "phone")
			phone_cooldown = 0.8

func _input(event: InputEvent) -> void:
	if not showing_newspaper or not newspaper_ready_for_input:
		return
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
		_dismiss_milestone_newspaper()
		get_viewport().set_input_as_handled()

func show_popup(text: String, auto_close_time: float = 0.0) -> void:
	popup_label.text = text
	cave_popup.visible = true
	popup_timer = 0.0
	popup_auto_close = auto_close_time
	# Center horizontally
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	cave_popup.position = Vector2((vp_size.x - 320) * 0.5, vp_size.y - 100)

func _close_popup() -> void:
	cave_popup.visible = false
	popup_auto_close = 0.0

func show_document_popup(text: String, title: String = "CAVE INSCRIPTION", kind: String = "paper") -> void:
	if showing_lore:
		return
	# "paper" = aged document; "phone" = dark burner-phone screen (NA texts)
	var is_phone: bool = kind == "phone"

	showing_lore = true
	lore_layer = CanvasLayer.new()
	lore_layer.layer = 90
	add_child(lore_layer)

	var vp_size: Vector2 = get_viewport().get_visible_rect().size

	var overlay := ColorRect.new()
	overlay.size = vp_size
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	lore_layer.add_child(overlay)

	var panel := PanelContainer.new()
	var panel_w: float = 380.0
	var panel_h: float = 240.0
	panel.position = Vector2((vp_size.x - panel_w) * 0.5, (vp_size.y - panel_h) * 0.5)
	panel.size = Vector2(panel_w, panel_h)
	panel.modulate = Color(1, 1, 1, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.08, 0.97) if is_phone else Color(0.92, 0.88, 0.78)
	style.border_color = Color(0.30, 0.50, 0.38) if is_phone else Color(0.3, 0.25, 0.2)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 0.60) if is_phone else Color(0.15, 0.12, 0.10))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.30, 0.50, 0.38, 0.5) if is_phone else Color(0.3, 0.25, 0.2, 0.5)
	sep_style.content_margin_top = 2
	sep_style.content_margin_bottom = 2
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	var body := Label.new()
	body.text = text
	body.add_theme_font_size_override("font_size", 8)
	body.add_theme_color_override("font_color", Color(0.72, 0.88, 0.75) if is_phone else Color(0.18, 0.15, 0.12))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body)

	var prompt := Label.new()
	prompt.text = "[Press any key to close]"
	prompt.add_theme_font_size_override("font_size", 9)
	prompt.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(prompt)

	overlay.add_child(panel)

	# Fade in
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(overlay, "color:a", 0.7, 0.4)
	tw.tween_property(panel, "modulate:a", 1.0, 0.4)
	tw.set_parallel(false)
	tw.tween_interval(0.3)
	tw.tween_callback(func() -> void:
		_wait_for_lore_dismiss(overlay, panel, prompt)
	)

func show_lore_popup(text: String) -> void:
	show_document_popup(text, "CAVE INSCRIPTION")

func _wait_for_lore_dismiss(overlay: ColorRect, panel: PanelContainer, prompt: Label) -> void:
	var elapsed_ref: Array[float] = [0.0]
	var dismissed: Array[bool] = [false]
	var layer_ref: CanvasLayer = lore_layer
	var check_fn: Callable
	check_fn = func(delta_val: float) -> void:
		if dismissed[0]:
			return
		elapsed_ref[0] += delta_val
		prompt.modulate.a = 0.5 + 0.5 * sin(elapsed_ref[0] * 2.0)
		if Input.is_action_just_pressed("scoop") or Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("ui_accept"):
			dismissed[0] = true
			var tw_out := create_tween()
			tw_out.set_parallel(true)
			tw_out.tween_property(overlay, "color:a", 0.0, 0.3)
			tw_out.tween_property(panel, "modulate:a", 0.0, 0.3)
			tw_out.set_parallel(false)
			tw_out.tween_interval(0.2)
			tw_out.tween_callback(func() -> void:
				layer_ref.queue_free()
				showing_lore = false
				lore_layer = null
			)
	get_tree().process_frame.connect(func() -> void:
		if is_instance_valid(layer_ref):
			check_fn.call(get_process_delta_time())
	)

func _on_loot_collected(_cave_id: String, _loot_id: String, reward_text: String) -> void:
	show_document_popup(reward_text, "CAVE DISCOVERY")

# Queues a one-shot NA text beat; no-op if this save has already seen it.
func _queue_na_text(key: String) -> void:
	if not NA_TEXTS.has(key):
		return
	if not GameManager.mark_story_flag("na_text_" + key):
		return
	for msg in NA_TEXTS[key]:
		phone_queue.append(msg)
	# First text of a batch waits a few seconds so a milestone newspaper
	# (fired 2s after pool completion) goes first.
	phone_cooldown = maxf(phone_cooldown, 3.5)

func _on_story_swamp_completed(swamp_index: int, _reward: float) -> void:
	match swamp_index:
		1: _queue_na_text("pond")
		3: _queue_na_text("bog")
		5: _queue_na_text("lake")
		7: _queue_na_text("lagoon")
		8: _queue_na_text("bayou")
		9: _queue_na_text("atlantic")

func _on_swamp_completed(swamp_index: int, _reward: float) -> void:
	# Skip milestone newspaper for Atlantic (pool 9) — endgame cinematic handles it
	if swamp_index == 9:
		return
	# Show milestone newspaper after a short delay
	if swamp_index >= 0 and swamp_index < milestone_newspapers.size():
		var idx: int = swamp_index
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			_show_milestone_newspaper(idx)
		)

func _init_milestone_newspapers() -> void:
	milestone_newspapers = [
		{
			"date": "Vol. XLII, No. 8 — Friday, March 15",
			"headline": "SWAMP EMPLOYEE SOMEHOW DRAINS PUDDLE",
			"subhead": "Government takes credit; allocates $0 for further progress",
			"body": "\"This proves the system works,\" said Press Secretary Spinwell at a hastily organized press conference. When asked how a man with no tools managed to drain a puddle, Spinwell responded, \"American ingenuity,\" before being escorted away by aides.\n\nSenator Swampsworth released a statement taking personal credit for the puddle's removal, calling it \"a direct result of my leadership.\" Records show he has never visited the swamp.\n\nCongressman Goodwell (I) called the achievement \"proof that one honest worker can outperform an entire bureaucracy.\" He has introduced a bill to increase the field operations budget."
		},
		{
			"date": "Vol. XLII, No. 12 — Tuesday, March 19",
			"headline": "SWAMP MAN CONTINUES, POLITICIANS MILDLY ANNOYED",
			"subhead": "\"We didn't think he'd still be here,\" admits unnamed official",
			"body": "The lone swamp drainer has now cleared a second body of water, prompting mild concern among government officials who assumed he would have quit by now.\n\n\"The plan was for him to get discouraged and leave,\" said an anonymous source. \"Nobody actually wants the swamp drained. Have you seen what's in there?\"\n\nOnly Congressman Goodwell voted against a motion to \"quietly reassign\" the drainer. \"Let the man work,\" he said."
		},
		{
			"date": "Vol. XLII, No. 19 — Tuesday, March 26",
			"headline": "DRAINING REVEALS BURIED CAMPAIGN SIGNS FROM 1987",
			"subhead": "\"Those were supposed to stay buried,\" says nervous city councilman",
			"body": "The draining of the marsh has uncovered hundreds of old campaign signs, several unmarked filing cabinets, and what appears to be a shredded Rolodex belonging to a former mayor.\n\nCity officials have requested that the drainer \"please stop finding things.\" A cease-and-desist letter was drafted but could not be delivered because no one knows the drainer's name.\n\nCongressman Goodwell has filed a formal complaint about missing funds in the Initiative budget. \"Someone is going to answer for this,\" he said."
		},
		{
			"date": "Vol. XLII, No. 28 — Thursday, April 4",
			"headline": "SCIENTISTS WARN: DRAINING SWAMP \"COULD DISRUPT ECOSYSTEM\"",
			"subhead": "Study funded by Senator Swampsworth's wife's foundation",
			"body": "A new study warns that continued swamp draining could endanger several species of mosquito and an \"unusually large\" population of leeches.\n\n\"Won't somebody think of the mosquitoes?\" pleaded a lobbyist from the newly formed Americans for Swamp Preservation. The organization was registered yesterday and lists its address as Senator Swampsworth's vacation home.\n\nCongressman Goodwell, recently appointed chair of the Swamp Oversight Committee, said the study \"raises valid concerns\" and recommended \"a measured pace.\" He was later seen at the same donor dinner as Swampsworth.\n\nOfficials have ordered \"emergency water rerouting\" to adjacent bodies of water, citing \"ecological balance.\"",
			"photo": "[Photo: Senator at \"swamp research\" resort]"
		},
		{
			"date": "Vol. XLII, No. 35 — Thursday, April 11",
			"headline": "ACTUAL SWAMP NOW DRAINED, GOVERNMENT IN EMERGENCY SESSION",
			"subhead": "Congress votes to rename remaining water \"Definitely Not A Swamp\"",
			"body": "In an unprecedented move, Congress held an emergency session to address the fact that the swamp has been drained. A bipartisan resolution was passed to reclassify all remaining bodies of water as \"Definitely Not Swamps.\"\n\n\"You can't drain what isn't a swamp,\" explained Congresswoman Lobbyton, visibly sweating. Legal experts say the reclassification has no practical effect.\n\nCongressman Goodwell was notably absent from the emergency session. His office said he was \"consulting with stakeholders.\" The stakeholders were later identified as SwampCo board members."
		},
		{
			"date": "Vol. XLII, No. 44 — Saturday, April 20",
			"headline": "MAN WITH BUCKET OUTPERFORMS ENTIRE GOVERNMENT PROGRAM",
			"subhead": "$200M initiative has produced 0 results; one guy has drained 6 bodies of water",
			"body": "An audit of the Swamp Draining Initiative reveals that of the $200M budget, $0 was spent on actual draining. Meanwhile, one man with purchased tools has drained six bodies of water.\n\nThe Consultant's latest $500,000 report recommends \"continued monitoring.\" It is three pages long and two of them are the cover page.\n\nCongressman Goodwell declined to comment on the audit findings, calling it \"a distraction from the real issues.\" He has purchased a lakefront property.\n\nGovernment tanker trucks were spotted dumping water into the reservoir overnight. Officials deny everything.",
			"photo": "[Photo: Man with bucket, Senate building background]"
		},
		{
			"date": "Vol. XLII, No. 53 — Monday, April 29",
			"headline": "BOTH PARTIES ISSUE RARE JOINT STATEMENT: \"STOP DRAINING\"",
			"subhead": "Republicans and Democrats agree for first time since naming a post office",
			"body": "In what historians are calling \"the most bipartisan moment in decades,\" both parties have jointly demanded that the swamp drainer cease all operations immediately.\n\n\"Some things should stay wet,\" said Senator Swampsworth. \"The swamp is part of our national heritage,\" added Congresswoman Lobbyton. Neither could explain why they suddenly care about swamp preservation.\n\nCongressman Goodwell co-signed the joint statement, calling the drainer's work \"reckless and irresponsible.\" His campaign has received $400,000 from Americans for Swamp Preservation."
		},
		{
			"date": "Vol. XLII, No. 61 — Tuesday, May 7",
			"headline": "LEAKED DOCUMENTS SHOW POLITICIANS STORED VALUABLES IN SWAMP",
			"subhead": "\"It's not corruption, it's 'waterproof asset management,'\" says lawyer",
			"body": "Draining of the lagoon has revealed waterproof containers belonging to multiple elected officials. Contents include offshore account records, blackmail photographs, and what appears to be \"a truly staggering amount of cash.\"\n\nA spokesperson for the implicated officials called the discovery \"a coincidence\" and suggested the containers \"must have floated there from somewhere else.\"\n\nAmong the waterproof containers: a folder labeled \"Goodwell — Phase 2.\" Contents not yet disclosed. Goodwell's office called it \"opposition research that was planted.\"\n\nIn a final act of defiance, fire hydrants across the county were opened simultaneously, flooding the bayou with municipal water. The water bill was charged to \"field operations.\"",
			"photo": "[Photo: Waterproof containers pulled from swamp]"
		},
		{
			"date": "Vol. XLII, No. 70 — Thursday, May 16",
			"headline": "POLITICIANS FLEE COUNTRY AS BAYOU DRAINAGE REVEALS PAPER TRAIL",
			"subhead": "Senator Swampsworth's passport found; he's \"on vacation indefinitely\"",
			"body": "At least fourteen elected officials have left the country following the draining of the bayou, which exposed a comprehensive paper trail linking both parties to decades of corruption.\n\nSenator Swampsworth was last seen boarding a private jet to a \"non-extradition country.\" His office says he is \"on a fact-finding mission\" and will return \"when the swamp refills.\"\n\nCongressman Goodwell remains in the country, having been promoted to Senate Majority Leader following \"several vacancies.\" He has announced a new initiative to \"protect our waterways.\"",
			"photo": "[Photo: Empty congressional parking lot]"
		},
		{
			"date": "Vol. XLII, No. 82 — Friday, May 30",
			"headline": "THE ATLANTIC OCEAN IS DRAINING AND IT'S ONE MAN'S FAULT",
			"subhead": "\"We should have given him a shovel,\" admits former Press Secretary",
			"body": "Former Press Secretary Spinwell, speaking from an undisclosed location, expressed regret over the government's handling of the swamp drainer. \"In hindsight, maybe we should have just given him a shovel and let him drain the puddle. Instead we gave him nothing and he drained the ocean.\"\n\nThe drainer could not be reached for comment. He was last seen heading east with a very large bucket.\n\nSenate Majority Leader Goodwell denounced the drainer as \"an enemy of the wetlands\" and signed an executive order to \"restore and protect the swamp.\" He was last seen touring a private island with real estate developers.",
			"photo": "[Photo: One man. One bucket. One ocean.]"
		}
	]

func _build_newspaper_overlay() -> void:
	newspaper_layer = CanvasLayer.new()
	newspaper_layer.layer = 95
	add_child(newspaper_layer)

	var vp_size: Vector2 = Vector2(640, 360)

	newspaper_overlay = ColorRect.new()
	newspaper_overlay.size = vp_size
	newspaper_overlay.color = Color(0, 0, 0, 0.0)
	newspaper_overlay.visible = false
	newspaper_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	newspaper_layer.add_child(newspaper_overlay)

	newspaper_panel = PanelContainer.new()
	var panel_w: float = 400.0
	var panel_h: float = 280.0
	var panel_x: float = (vp_size.x - panel_w) * 0.5
	var panel_y: float = (vp_size.y - panel_h) * 0.5
	newspaper_panel.position = Vector2(panel_x, panel_y)
	newspaper_panel.size = Vector2(panel_w, panel_h)
	newspaper_panel.modulate = Color(1, 1, 1, 0)

	newspaper_paper_style = StyleBoxFlat.new()
	newspaper_paper_style.bg_color = Color(0.92, 0.88, 0.78)
	newspaper_paper_style.border_color = Color(0.3, 0.25, 0.2)
	newspaper_paper_style.border_width_top = 2
	newspaper_paper_style.border_width_bottom = 2
	newspaper_paper_style.border_width_left = 2
	newspaper_paper_style.border_width_right = 2
	newspaper_paper_style.corner_radius_top_left = 2
	newspaper_paper_style.corner_radius_top_right = 2
	newspaper_paper_style.corner_radius_bottom_left = 2
	newspaper_paper_style.corner_radius_bottom_right = 2
	newspaper_paper_style.content_margin_left = 16
	newspaper_paper_style.content_margin_right = 16
	newspaper_paper_style.content_margin_top = 12
	newspaper_paper_style.content_margin_bottom = 12
	newspaper_panel.add_theme_stylebox_override("panel", newspaper_paper_style)

	# Corner fold — small triangle in top-right corner
	newspaper_corner_fold = Polygon2D.new()
	var fold_size: float = 14.0
	newspaper_corner_fold.polygon = PackedVector2Array([
		Vector2(panel_x + panel_w - fold_size, panel_y),
		Vector2(panel_x + panel_w, panel_y),
		Vector2(panel_x + panel_w, panel_y + fold_size),
	])
	newspaper_corner_fold.color = Color(0.78, 0.74, 0.64)
	newspaper_corner_fold.z_index = 1
	newspaper_overlay.add_child(newspaper_corner_fold)

	# Coffee ring stain — subtle brown circle, hidden by default
	newspaper_coffee_stain = Polygon2D.new()
	var ring_points := PackedVector2Array()
	var ring_radius: float = 18.0
	var ring_inner: float = 14.0
	for a in range(24):
		var angle: float = a * TAU / 24.0
		ring_points.append(Vector2(cos(angle) * ring_radius, sin(angle) * ring_radius))
	for a in range(24, 0, -1):
		var angle: float = (a - 1) * TAU / 24.0
		ring_points.append(Vector2(cos(angle) * ring_inner, sin(angle) * ring_inner))
	newspaper_coffee_stain.polygon = ring_points
	newspaper_coffee_stain.color = Color(0.45, 0.30, 0.15, 0.10)
	newspaper_coffee_stain.z_index = 1
	newspaper_coffee_stain.visible = false
	newspaper_overlay.add_child(newspaper_coffee_stain)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	newspaper_panel.add_child(vbox)

	var masthead := Label.new()
	masthead.text = "THE SWAMP GAZETTE"
	masthead.add_theme_font_size_override("font_size", 16)
	masthead.add_theme_color_override("font_color", Color(0.15, 0.12, 0.10))
	masthead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(masthead)

	newspaper_date_label = Label.new()
	newspaper_date_label.add_theme_font_size_override("font_size", 8)
	newspaper_date_label.add_theme_color_override("font_color", Color(0.4, 0.38, 0.35))
	newspaper_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(newspaper_date_label)

	var sep1 := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.3, 0.25, 0.2, 0.5)
	sep_style.content_margin_top = 2
	sep_style.content_margin_bottom = 2
	sep1.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep1)

	newspaper_headline = Label.new()
	newspaper_headline.add_theme_font_size_override("font_size", 12)
	newspaper_headline.add_theme_color_override("font_color", Color(0.12, 0.10, 0.08))
	newspaper_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	newspaper_headline.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(newspaper_headline)

	newspaper_subhead = Label.new()
	newspaper_subhead.add_theme_font_size_override("font_size", 9)
	newspaper_subhead.add_theme_color_override("font_color", Color(0.35, 0.32, 0.28))
	newspaper_subhead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	newspaper_subhead.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(newspaper_subhead)

	var sep2 := HSeparator.new()
	var sep_style2 := StyleBoxFlat.new()
	sep_style2.bg_color = Color(0.3, 0.25, 0.2, 0.5)
	sep_style2.content_margin_top = 2
	sep_style2.content_margin_bottom = 2
	sep2.add_theme_stylebox_override("separator", sep_style2)
	vbox.add_child(sep2)

	# Photo placeholder — gray box with italic caption, hidden by default
	newspaper_photo_label = Label.new()
	newspaper_photo_label.add_theme_font_size_override("font_size", 7)
	newspaper_photo_label.add_theme_color_override("font_color", Color(0.45, 0.42, 0.38))
	newspaper_photo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	newspaper_photo_label.visible = false
	var photo_style := StyleBoxFlat.new()
	photo_style.bg_color = Color(0.72, 0.68, 0.60)
	photo_style.content_margin_left = 8
	photo_style.content_margin_right = 8
	photo_style.content_margin_top = 6
	photo_style.content_margin_bottom = 6
	newspaper_photo_label.add_theme_stylebox_override("normal", photo_style)
	vbox.add_child(newspaper_photo_label)

	newspaper_body = Label.new()
	newspaper_body.add_theme_font_size_override("font_size", 8)
	newspaper_body.add_theme_color_override("font_color", Color(0.18, 0.15, 0.12))
	newspaper_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	newspaper_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(newspaper_body)

	newspaper_prompt = Label.new()
	newspaper_prompt.text = "[Press any key to continue]"
	newspaper_prompt.add_theme_font_size_override("font_size", 10)
	newspaper_prompt.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	newspaper_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(newspaper_prompt)

	newspaper_overlay.add_child(newspaper_panel)

# On repeat runs the first paper acknowledges the loop instead of replaying verbatim.
const PRESTIGE_PUDDLE_NEWSPAPER: Dictionary = {
	"date": "Vol. XLIII, No. 1 — the following spring",
	"headline": "SWAMP EMPLOYEE DRAINS PUDDLE. AGAIN.",
	"subhead": "\"Wait, the same guy?\" asks entire government",
	"body": "The puddle is gone. Again. Officials who spent $400M refilling the swamp expressed outrage that \"the drainage issue has resumed.\"\n\nPress Secretary Spinwell, reading from last year's statement with the dates crossed out, called it \"proof the system works, still.\"\n\nA foreign data-analytics consulting firm declined to comment, but was described by witnesses as \"visibly pleased.\""
}

func _show_milestone_newspaper(swamp_index: int) -> void:
	if showing_newspaper:
		return
	var data: Dictionary = milestone_newspapers[swamp_index]
	if swamp_index == 0 and GameManager.prestige_count >= 1:
		data = PRESTIGE_PUDDLE_NEWSPAPER
	newspaper_date_label.text = data["date"]
	newspaper_headline.text = data["headline"]
	newspaper_subhead.text = data["subhead"]
	newspaper_body.text = data["body"]

	# Age tinting by act
	var age_colors: Array[Color] = [
		Color(0.92, 0.88, 0.78),  # Act 1 (pools 0-2) — clean
		Color(0.90, 0.85, 0.72),  # Act 2 (pools 3-5) — slightly aged
		Color(0.86, 0.80, 0.66),  # Act 3 (pools 6-8) — yellowed
		Color(0.82, 0.76, 0.60),  # Act 4 (pool 9) — old
	]
	var act: int = 0
	if swamp_index >= 9:
		act = 3
	elif swamp_index >= 6:
		act = 2
	elif swamp_index >= 3:
		act = 1
	newspaper_paper_style.bg_color = age_colors[act]

	# Corner fold color matches paper but darker
	var fold_color: Color = age_colors[act].darkened(0.15)
	newspaper_corner_fold.color = fold_color

	# Coffee stain — only Act 2+
	if act >= 1:
		newspaper_coffee_stain.visible = true
		var panel_x: float = newspaper_panel.position.x
		var panel_y: float = newspaper_panel.position.y
		# Deterministic position based on swamp_index
		var coffee_offsets: Array[Vector2] = [
			Vector2(0, 0), Vector2(0, 0), Vector2(0, 0),  # Act 1 — unused
			Vector2(320, 180),  # pool 3
			Vector2(280, 220),  # pool 4
			Vector2(350, 160),  # pool 5
			Vector2(260, 200),  # pool 6
			Vector2(340, 240),  # pool 7
			Vector2(300, 170),  # pool 8
			Vector2(310, 210),  # pool 9
		]
		newspaper_coffee_stain.position = coffee_offsets[swamp_index]
		newspaper_coffee_stain.color.a = 0.08 + float(act) * 0.02
	else:
		newspaper_coffee_stain.visible = false

	# Photo placeholder
	if data.has("photo"):
		newspaper_photo_label.text = data["photo"]
		newspaper_photo_label.visible = true
	else:
		newspaper_photo_label.visible = false

	showing_newspaper = true
	newspaper_ready_for_input = false
	newspaper_overlay.visible = true

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(newspaper_overlay, "color:a", 0.7, 0.5)
	tw.tween_property(newspaper_panel, "modulate:a", 1.0, 0.5)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void: newspaper_ready_for_input = true)

func _dismiss_milestone_newspaper() -> void:
	newspaper_ready_for_input = false
	showing_newspaper = false
	# If there are more endgame newspapers queued, show the next one
	if endgame_active and endgame_newspaper_queue.size() > 0:
		var next_data: Dictionary = endgame_newspaper_queue.pop_front()
		var tw := create_tween()
		tw.tween_property(newspaper_panel, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func() -> void:
			_show_newspaper_data(next_data)
		)
		return
	# If endgame sequence just finished, go to title
	if endgame_active:
		endgame_active = false
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(newspaper_overlay, "color:a", 0.0, 0.5)
		tw.tween_property(newspaper_panel, "modulate:a", 0.0, 0.5)
		tw.set_parallel(false)
		tw.tween_interval(0.3)
		tw.tween_callback(func() -> void:
			newspaper_overlay.visible = false
			transition_to_scene("res://scenes/title_screen.tscn")
		)
		return
	# Normal milestone dismiss
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(newspaper_overlay, "color:a", 0.0, 0.4)
	tw.tween_property(newspaper_panel, "modulate:a", 0.0, 0.4)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void:
		newspaper_overlay.visible = false
	)

# One standalone newspaper (e.g. "IT'S GONE" when the Atlantic drains) —
# dismisses back to gameplay instead of rolling into the endgame queue.
func show_single_newspaper(data: Dictionary) -> void:
	if showing_newspaper:
		return
	_show_newspaper_data(data)

func show_endgame_newspapers(newspapers: Array) -> void:
	if newspapers.size() == 0:
		return
	endgame_active = true
	endgame_newspaper_queue = newspapers.duplicate()
	var first: Dictionary = endgame_newspaper_queue.pop_front()
	_show_newspaper_data(first)

func _show_newspaper_data(data: Dictionary) -> void:
	newspaper_date_label.text = data.get("date", "SPECIAL EDITION")
	newspaper_headline.text = data.get("headline", "")
	newspaper_subhead.text = data.get("subhead", "")
	newspaper_body.text = data.get("body", "")
	# Aged paper for endgame
	newspaper_paper_style.bg_color = Color(0.82, 0.76, 0.60)
	newspaper_corner_fold.color = Color(0.82, 0.76, 0.60).darkened(0.15)
	newspaper_coffee_stain.visible = true
	newspaper_coffee_stain.position = Vector2(310, 210)
	newspaper_coffee_stain.color.a = 0.12
	if data.has("photo"):
		newspaper_photo_label.text = data["photo"]
		newspaper_photo_label.visible = true
	else:
		newspaper_photo_label.visible = false
	# Update prompt text — only the last endgame card returns to title
	if endgame_active and endgame_newspaper_queue.size() == 0:
		newspaper_prompt.text = "[Press any key to return to title]"
	else:
		newspaper_prompt.text = "[Press any key to continue]"
	showing_newspaper = true
	newspaper_ready_for_input = false
	newspaper_overlay.visible = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(newspaper_overlay, "color:a", 0.7, 0.5)
	tw.tween_property(newspaper_panel, "modulate:a", 1.0, 0.5)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void: newspaper_ready_for_input = true)

# --- Ending choice (island climax) ---
var ending_choice_layer: CanvasLayer = null

# Modal binary choice at the island: hand the Guest List to NA, or swing.
# Calls on_choice with "hand_over" or "swing" after the panel closes.
func show_ending_choice(on_choice: Callable) -> void:
	if ending_choice_layer != null:
		return
	ending_choice_layer = CanvasLayer.new()
	ending_choice_layer.layer = 96
	add_child(ending_choice_layer)

	var vp_size: Vector2 = get_viewport().get_visible_rect().size

	var overlay := ColorRect.new()
	overlay.size = vp_size
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ending_choice_layer.add_child(overlay)

	var panel := PanelContainer.new()
	var panel_w: float = 430.0
	var panel_h: float = 210.0
	panel.position = Vector2((vp_size.x - panel_w) * 0.5, (vp_size.y - panel_h) * 0.5)
	panel.size = Vector2(panel_w, panel_h)
	panel.modulate = Color(1, 1, 1, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.08, 0.97)
	style.border_color = Color(0.55, 0.50, 0.35)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "THE GUEST LIST"
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.78, 0.45))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var body := Label.new()
	body.text = "Seven officials. One mansion. Nowhere left to hide.\n\nThe burner phone buzzes once: \"The List. Now. — NA\"\n\nIn your bag: every name, every date, every flight.\nIn your hand: the hammer you came here to swing."
	body.add_theme_font_size_override("font_size", 9)
	body.add_theme_color_override("font_color", Color(0.82, 0.80, 0.72))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var make_btn := func(label_text: String, choice: String, accent: Color) -> Button:
		var b := Button.new()
		b.text = label_text
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_color_override("font_color", accent)
		b.custom_minimum_size = Vector2(160, 28)
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.13, 0.12, 0.10)
		bs.border_color = accent.darkened(0.3)
		bs.border_width_top = 1
		bs.border_width_bottom = 1
		bs.border_width_left = 1
		bs.border_width_right = 1
		b.add_theme_stylebox_override("normal", bs)
		var bs_hover: StyleBoxFlat = bs.duplicate()
		bs_hover.bg_color = Color(0.20, 0.18, 0.14)
		b.add_theme_stylebox_override("hover", bs_hover)
		b.add_theme_stylebox_override("focus", bs_hover)
		b.pressed.connect(func() -> void:
			var layer_ref: CanvasLayer = ending_choice_layer
			ending_choice_layer = null
			if is_instance_valid(layer_ref):
				layer_ref.queue_free()
			on_choice.call(choice)
		)
		return b

	var hand_btn: Button = make_btn.call("HAND OVER THE LIST", "hand_over", Color(0.55, 0.85, 0.60))
	btn_row.add_child(hand_btn)
	btn_row.add_child(make_btn.call("SWING", "swing", Color(0.95, 0.55, 0.45)))

	overlay.add_child(panel)
	hand_btn.grab_focus()

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(overlay, "color:a", 0.75, 0.6)
	tw.tween_property(panel, "modulate:a", 1.0, 0.6)

# --- Scene Transitions ---
func transition_to_scene(scene_path: String, use_pixelate: bool = false) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	if use_pixelate:
		_pixelate_out(func() -> void: _do_scene_change(scene_path))
	else:
		var tw := create_tween()
		tw.tween_property(fade_rect, "color:a", 1.0, 0.4)
		tw.tween_callback(_do_scene_change.bind(scene_path))

func _do_scene_change(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
	# Fade in after one frame (let new scene _ready run)
	await get_tree().process_frame
	_fade_in()

func transition_to_return() -> void:
	if OS.get_environment("DTS_FREEZE") != "":
		return  # debug-only: hold the scene for screenshots (never set in real builds)
	if is_transitioning:
		return
	is_transitioning = true
	_pixelate_out(func() -> void: _do_scene_change(return_scene_path))

func fade_in() -> void:
	_fade_in()

func _fade_in() -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 0.4)
	tw.tween_callback(func() -> void: is_transitioning = false)

func _pixelate_out(on_complete: Callable) -> void:
	# Quick fade with brief white flash, then black
	var tw := create_tween()
	fade_rect.color = Color(1, 1, 1, 0)
	tw.tween_property(fade_rect, "color:a", 0.7, 0.1)
	tw.tween_callback(func() -> void: fade_rect.color = Color(0, 0, 0, 0.7))
	tw.tween_property(fade_rect, "color:a", 1.0, 0.2)
	tw.tween_callback(func() -> void: on_complete.call())

func flash_white(duration: float = 0.15) -> void:
	# Brief white flash for celebrations (pool completion, etc.)
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.6)
	flash.anchors_preset = Control.PRESET_FULL_RECT
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, duration)
	tw.tween_callback(flash.queue_free)
