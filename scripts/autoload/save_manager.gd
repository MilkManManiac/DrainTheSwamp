extends Node

const SAVE_PATH: String = "user://save_data.json"
const TMP_PATH: String = "user://save_data.json.tmp"
const BACKUP_PATH: String = "user://save_data.json.bak"
const CORRUPT_PATH: String = "user://save_data.corrupt.json"
const NEWER_COPY_PATH: String = "user://save_data.newer.json"
const SAVE_INTERVAL: float = 30.0

var save_timer: float = 0.0

func _ready() -> void:
	load_game()
	# Save on the big irreversible moments, not just the 30s timer — on web,
	# closing the tab never fires WM_CLOSE, so timer-only means lost progress.
	GameManager.swamp_completed.connect(func(_i: int, _r: float) -> void: save_game())
	GameManager.prestige_performed.connect(save_game)

func _process(delta: float) -> void:
	save_timer += delta
	if save_timer >= SAVE_INTERVAL:
		save_timer = 0.0
		save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Browser tab switch / minimize — best-effort save (WM_CLOSE is unreliable on web).
		save_game()

func save_game() -> void:
	var data: Dictionary = GameManager.get_save_data()
	var json_string: String = JSON.stringify(data, "\t")
	# Atomic-ish write: write to a temp file first so a crash mid-write can never
	# truncate the live save, then rotate live -> .bak and tmp -> live.
	var file := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: cannot open %s for writing" % TMP_PATH)
		return
	file.store_string(json_string)
	file.close()
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(BACKUP_PATH):
			DirAccess.remove_absolute(BACKUP_PATH)
		DirAccess.rename_absolute(SAVE_PATH, BACKUP_PATH)
	DirAccess.rename_absolute(TMP_PATH, SAVE_PATH)

func load_game() -> void:
	if _try_load(SAVE_PATH):
		return
	if FileAccess.file_exists(SAVE_PATH):
		# Main save exists but didn't parse. Preserve it so the 30s autosave can't
		# clobber a recoverable file, then fall back to the backup.
		push_warning("SaveManager: main save corrupt — preserved at %s, trying backup" % CORRUPT_PATH)
		if FileAccess.file_exists(CORRUPT_PATH):
			DirAccess.remove_absolute(CORRUPT_PATH)
		DirAccess.rename_absolute(SAVE_PATH, CORRUPT_PATH)
	if _try_load(BACKUP_PATH):
		push_warning("SaveManager: loaded from backup save")

func _try_load(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var json_string: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_string) != OK:
		return false
	var data = json.get_data()
	if not (data is Dictionary):
		return false
	# Save written by a NEWER build (Steam Cloud sync onto an old install): loading
	# drops fields this build doesn't know, and the next autosave would destroy them.
	# Keep an untouched copy so upgrading the game restores full progress.
	var save_version: int = int(data.get("version", 1))
	if save_version > GameManager.SAVE_VERSION and not FileAccess.file_exists(NEWER_COPY_PATH):
		push_warning("SaveManager: save v%d is newer than this build (v%d) — copy kept at %s"
			% [save_version, GameManager.SAVE_VERSION, NEWER_COPY_PATH])
		var copy := FileAccess.open(NEWER_COPY_PATH, FileAccess.WRITE)
		if copy:
			copy.store_string(json_string)
			copy.close()
	GameManager.load_save_data(data)
	return true
