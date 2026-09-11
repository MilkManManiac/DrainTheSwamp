extends Node2D
## v3 critters: tiny pixel-strip sprites for frog/turtle/fish/tadpole/bird/
## dragonfly/butterfly, replacing the old coloured-ColorRect wildlife.
##
## This module is a sprite factory only. game_world.gd still owns placement
## (pool geometry, counts, spawn timers) and per-frame animation; it just
## calls make_*() here instead of building ColorRect parts, guarded by
## V3_CRITTERS. See docs/plans/pixel-art-revamp-2026-09-11.md, track 4.

var world: Node2D = null  # game_world.gd instance, set by caller before add_child

const FROG_TEX: Texture2D = preload("res://assets/art/drainsville/frog.png")
const TURTLE_TEX: Texture2D = preload("res://assets/art/drainsville/turtle.png")
const FISH_TEX: Texture2D = preload("res://assets/art/drainsville/catfish.png")
const BIRD_TEX: Texture2D = preload("res://assets/art/drainsville/bird.png")
const DRAGONFLY_TEX: Texture2D = preload("res://assets/art/drainsville/dragonfly.png")
const BUTTERFLY_TEX: Texture2D = preload("res://assets/art/drainsville/butterfly.png")
const TADPOLE_TEX: Texture2D = preload("res://assets/art/drainsville/tadpole.png")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _strip(tex: Texture2D, frames: int, frame: int = 0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = frames
	s.frame = frame
	s.centered = true
	s.scale = Vector2(0.5, 0.5)
	return s

## Frogs sit on a lily pad (parented to the pad node); body drawn a few px up.
func make_frog() -> Sprite2D:
	var s := _strip(FROG_TEX, 2)
	s.position = Vector2(0, -4)
	return s

func make_turtle() -> Sprite2D:
	return _strip(TURTLE_TEX, 2, randi() % 2)

func make_fish() -> Sprite2D:
	return _strip(FISH_TEX, 3, randi() % 3)

func make_tadpole() -> Sprite2D:
	return _strip(TADPOLE_TEX, 2, randi() % 2)

func make_bird() -> Sprite2D:
	return _strip(BIRD_TEX, 3)

func make_dragonfly() -> Sprite2D:
	return _strip(DRAGONFLY_TEX, 2)

func make_butterfly() -> Sprite2D:
	return _strip(BUTTERFLY_TEX, 2)
