extends Node
class_name EventLawDemoObserver
## Purpose/Goal: Observe demo buses and print concise traces to validate event routing.
## Design Pattern/Principle: Non-authoritative listener aggregator.
## Source/Reference: `hex_map/development-guides/game-law-event-architecture.md`.
## Expected Behavior/Usage: Attach in demo scene and assign bus paths.
## Scope: Debug/visibility only.
## Break Risks: Treating this observer output as authority is incorrect.
## Timestamp: 2026-02-25 20:12:00 UTC

@export var gameplay_event_bus_path: NodePath
@export var ui_event_bus_path: NodePath
@export var audio_event_bus_path: NodePath
@export var camera_event_bus_path: NodePath
@export var vfx_event_bus_path: NodePath

var _trace_lines: PackedStringArray = []


func _ready() -> void:
	var gameplay_event_bus := get_node_or_null(gameplay_event_bus_path)
	var ui_event_bus := get_node_or_null(ui_event_bus_path)
	var audio_event_bus := get_node_or_null(audio_event_bus_path)
	var camera_event_bus := get_node_or_null(camera_event_bus_path)
	var vfx_event_bus := get_node_or_null(vfx_event_bus_path)

	if gameplay_event_bus != null:
		gameplay_event_bus.unit_damaged.connect(_on_unit_damaged)
		gameplay_event_bus.health_changed.connect(_on_health_changed)
		gameplay_event_bus.unit_defeated.connect(_on_unit_defeated)
		gameplay_event_bus.spell_resolved.connect(_on_spell_resolved)
	if ui_event_bus != null:
		ui_event_bus.show_damage_popup.connect(_on_ui_damage_popup)
	if audio_event_bus != null:
		audio_event_bus.play_hit_sfx.connect(_on_audio_hit_sfx)
	if camera_event_bus != null:
		camera_event_bus.request_screen_shake.connect(_on_camera_shake)
	if vfx_event_bus != null:
		vfx_event_bus.spawn_spell_impact_fx.connect(_on_vfx_impact)


func get_trace_lines() -> PackedStringArray:
	return _trace_lines


func _trace(line: String) -> void:
	_trace_lines.append(line)
	print("[EventLawDemo] %s" % line)


func _on_unit_damaged(event_id: StringName, target_unit_id: StringName, damage_amount: int, _damage_type: StringName, _crit_is_true: bool) -> void:
	_trace("Gameplay.unit_damaged id=%s target=%s damage=%d" % [event_id, target_unit_id, damage_amount])


func _on_health_changed(event_id: StringName, target_unit_id: StringName, old_health: int, new_health: int) -> void:
	_trace("Gameplay.health_changed id=%s target=%s %d->%d" % [event_id, target_unit_id, old_health, new_health])


func _on_unit_defeated(event_id: StringName, target_unit_id: StringName, reason: StringName) -> void:
	_trace("Gameplay.unit_defeated id=%s target=%s reason=%s" % [event_id, target_unit_id, reason])


func _on_spell_resolved(event_id: StringName, _caster_unit_id: StringName, _target_unit_id: StringName, _spell_id: StringName, outcome: StringName) -> void:
	_trace("Gameplay.spell_resolved id=%s outcome=%s" % [event_id, outcome])


func _on_ui_damage_popup(event_id: StringName, target_unit_id: StringName, damage_amount: int, _crit_is_true: bool) -> void:
	_trace("UI.show_damage_popup id=%s target=%s damage=%d" % [event_id, target_unit_id, damage_amount])


func _on_audio_hit_sfx(event_id: StringName, target_unit_id: StringName, damage_type: StringName) -> void:
	_trace("Audio.play_hit_sfx id=%s target=%s type=%s" % [event_id, target_unit_id, damage_type])


func _on_camera_shake(event_id: StringName, amplitude: float, duration_seconds: float) -> void:
	_trace("Camera.request_screen_shake id=%s amp=%.2f dur=%.2f" % [event_id, amplitude, duration_seconds])


func _on_vfx_impact(event_id: StringName, target_unit_id: StringName, effect_id: StringName) -> void:
	_trace("VFX.spawn_spell_impact_fx id=%s target=%s effect=%s" % [event_id, target_unit_id, effect_id])
