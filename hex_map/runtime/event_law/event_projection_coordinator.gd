extends Node
class_name EventProjectionCoordinator
## Purpose/Goal: Project authoritative gameplay events into non-authoritative presentation-domain buses.
## Design Pattern/Principle: Scene-root projection coordinator with one-way gameplay->presentation fanout.
## Source/Reference: `hex_map/docs/game-law-event-architecture.md` and presentation event pipeline contract.
## Expected Behavior/Usage: Assign bus node paths and place this coordinator at scene boundary.
## Scope: Projection only; no gameplay state mutation and no command resolution.
## Break Risks: Direct leaf-to-leaf fanout outside this coordinator reintroduces signal spaghetti.
## Timestamp: 2026-02-25 20:12:00 UTC

@export var gameplay_event_bus_path: NodePath
@export var ui_event_bus_path: NodePath
@export var audio_event_bus_path: NodePath
@export var camera_event_bus_path: NodePath
@export var vfx_event_bus_path: NodePath

var _gameplay_event_bus: Node = null
var _ui_event_bus: Node = null
var _audio_event_bus: Node = null
var _camera_event_bus: Node = null
var _vfx_event_bus: Node = null


func _ready() -> void:
	## Purpose/Goal: Wire one-time projection subscriptions at scene boundary.
	## Design Pattern/Principle: Centralized lifecycle-safe signal wiring.
	## Source/Reference: manager signal architecture workflow.
	## Expected Behavior/Usage: Called once per scene instantiation.
	## Scope: Connection setup only.
	## Break Risks: Missing paths silently disable projection; use assertions while integrating.
	## Timestamp: 2026-02-25 20:12:00 UTC
	_gameplay_event_bus = get_node_or_null(gameplay_event_bus_path)
	_ui_event_bus = get_node_or_null(ui_event_bus_path)
	_audio_event_bus = get_node_or_null(audio_event_bus_path)
	_camera_event_bus = get_node_or_null(camera_event_bus_path)
	_vfx_event_bus = get_node_or_null(vfx_event_bus_path)

	if _gameplay_event_bus == null:
		return

	if not _gameplay_event_bus.unit_damaged.is_connected(_on_unit_damaged):
		_gameplay_event_bus.unit_damaged.connect(_on_unit_damaged)
	if not _gameplay_event_bus.spell_resolved.is_connected(_on_spell_resolved):
		_gameplay_event_bus.spell_resolved.connect(_on_spell_resolved)


func _on_unit_damaged(
	event_id: StringName,
	target_unit_id: StringName,
	damage_amount: int,
	damage_type: StringName,
	crit_is_true: bool
) -> void:
	## Purpose/Goal: Project damage result into presentation buses.
	## Design Pattern/Principle: Deterministic projection fanout.
	## Source/Reference: spell-hit sequence in architecture contract.
	## Expected Behavior/Usage: Called from gameplay event bus after commit.
	## Scope: Presentation emissions only.
	## Break Risks: Emitting before authoritative commit would desync players from truth.
	## Timestamp: 2026-02-25 20:12:00 UTC
	if _ui_event_bus != null:
		_ui_event_bus.emit_show_damage_popup(event_id, target_unit_id, damage_amount, crit_is_true)
		_ui_event_bus.emit_show_unit_hit_flash(event_id, target_unit_id)
	if _audio_event_bus != null:
		_audio_event_bus.emit_play_hit_sfx(event_id, target_unit_id, damage_type)
	if _vfx_event_bus != null:
		_vfx_event_bus.emit_spawn_spell_impact_fx(event_id, target_unit_id, StringName("spell_hit_default"))


func _on_spell_resolved(
	event_id: StringName,
	_caster_unit_id: StringName,
	_target_unit_id: StringName,
	_spell_id: StringName,
	outcome: StringName
) -> void:
	if _camera_event_bus == null:
		return
	if outcome == StringName("hit") or outcome == StringName("crit"):
		_camera_event_bus.emit_request_screen_shake(event_id, 0.22, 0.12)
