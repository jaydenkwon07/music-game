extends Node
## Spawns the world-space visual for every played note (§7.4). Listens to the
## bus exactly like Synth does — one emitter, many listeners.
##
## Visuals always play, even in the instrument state (§6: "audio and visuals
## still play; only the effect is suppressed"), so this deliberately does NOT
## check NoteBus.effects_enabled(). Only gameplay effects gate on it.

func _ready() -> void:
	NoteBus.note_played.connect(_on_note_played)


func _on_note_played(midi: int, source: Vector2) -> void:
	if midi < 0:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var ring := NoteRing.new()
	scene.add_child(ring)
	ring.global_position = source
	ring.setup(NoteRegistry.color_for_midi(midi))
