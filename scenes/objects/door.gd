class_name Door
extends Interactable
## A melody-locked door (§5.10). Configured with only a melody id (§3); it composes
## a MelodyLock and shows the melody's STRUCTURE as gems — how many notes, their
## categories, and progress so far — at top-down scale. It never shows which notes
## (that is learned elsewhere; M2's gems are the only hint, D3).
##
## Interacting (space, via the Interactor) enters the instrument state and arms the
## lock. Play the melody: gems light one at a time; a wrong note resets them with a
## soft cue and no penalty (§6); the full melody opens the door for good.

@export var melody_id: String = ""
@export var slab_size: Vector2 = Vector2(24.0, 30.0)
## Gem radius and how far above the slab the gem row sits, in pixels.
@export var gem_radius: float = 2.5
@export var gem_margin: float = 5.0
## Seconds the soft mismatch cue lasts.
@export var mismatch_time: float = 0.35

var _lock: MelodyLock
var _targets: Array = []
var _progress: int = 0
var _total: int = 0
var _open: bool = false
var _mismatch_flash: float = 0.0  # remaining mismatch-cue time, seconds
var _blocker: CollisionShape2D


func _ready() -> void:
	# Reach past the slab so the player, stopped at the door's edge, is still in
	# interact range.
	radius = maxf(radius, slab_size.length())
	super._ready()

	_lock = MelodyLock.new()
	_lock.melody_id = melody_id
	add_child(_lock)
	_lock.unlocked.connect(_on_unlocked)
	_lock.progress_changed.connect(_on_progress)
	_lock.mismatch.connect(_on_mismatch)
	_total = _lock.total()
	_targets = _lock.target_midi()

	_add_blocker()
	NoteBus.instrument_state_changed.connect(_on_instrument_state_changed)


## A closed door blocks; interacting is pointless once it is open.
func can_interact() -> bool:
	return not _open


func interact(_player: Node2D) -> void:
	if _open or NoteBus.instrument_state_active:
		return
	# The real entry the Interactor's temporary fallback stood in for: enter the
	# instrument state and start listening on THIS door's melody.
	NoteBus.set_instrument_state(true)
	_lock.arm()


## The instrument state ended — either the player cancelled/exited (via the
## Interactor) or this door just opened. Either way stop listening and clear the
## gems; if we opened, the open visual takes over.
func _on_instrument_state_changed(active: bool) -> void:
	if active:
		return
	_lock.disarm()
	_progress = 0
	queue_redraw()


func _on_progress(progress: int, total: int) -> void:
	_progress = progress
	_total = total
	queue_redraw()


func _on_mismatch() -> void:
	_mismatch_flash = mismatch_time
	set_process(true)
	queue_redraw()


func _on_unlocked() -> void:
	_open = true
	# Stop blocking so M3 rooms behind the door become reachable.
	if _blocker != null:
		_blocker.set_deferred("disabled", true)
	NoteBus.set_instrument_state(false)
	queue_redraw()


func _process(delta: float) -> void:
	if _mismatch_flash > 0.0:
		_mismatch_flash = maxf(_mismatch_flash - delta, 0.0)
		queue_redraw()
	else:
		set_process(false)


func _add_blocker() -> void:
	var body := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = slab_size
	_blocker = CollisionShape2D.new()
	_blocker.shape = shape
	body.add_child(_blocker)
	add_child(body)


func _draw() -> void:
	_draw_slab()
	_draw_gems()


func _draw_slab() -> void:
	var rect := Rect2(-slab_size * 0.5, slab_size)
	if _open:
		# Hollow frame: the slab has swung away.
		draw_rect(rect, Color(0.10, 0.10, 0.13), false, 1.0)
	else:
		draw_rect(rect, Color(0.16, 0.15, 0.19), true)
		draw_rect(rect, Color(0.0, 0.0, 0.0, 0.5), false, 1.0)


func _draw_gems() -> void:
	if _total <= 0 or _open:
		return
	# One gem per melody note, centred in a row just above the slab.
	var spacing := gem_radius * 2.0 + 2.0
	var row_w := _total * spacing
	var start_x := -row_w * 0.5 + spacing * 0.5
	var y := -slab_size.y * 0.5 - gem_margin
	var flashing := _mismatch_flash > 0.0
	for i in _total:
		var base := NoteRegistry.color_for_midi(int(_targets[i]) if i < _targets.size() else -1)
		var col: Color
		if flashing:
			# Soft "no": the whole row falls to a dull desaturated grey briefly.
			col = base.darkened(0.6).lerp(Color(0.3, 0.28, 0.3), 0.7)
		elif i < _progress:
			col = base                      # lit: confirmed
		else:
			col = base.darkened(0.6)        # dim, but the target colour still reads
		var pos := Vector2(start_x + i * spacing, y)
		draw_circle(pos, gem_radius, col)
		draw_arc(pos, gem_radius, 0.0, TAU, 16, Color(0.0, 0.0, 0.0, 0.5), 1.0)
