extends Node
class_name UIEventBus
## Purpose/Goal: Route presentation-only UI events derived from authoritative gameplay outcomes.
## Design Pattern/Principle: Presentation bus with non-authoritative payloads.
## Source/Reference: `hex_map/development-guides/game-law-event-architecture.md`.
## Expected Behavior/Usage: Projection coordinator emits; UI controllers consume.
## Scope: UI presentation only.
## Break Risks: Treating UI events as gameplay truth introduces authority inversion.
## Timestamp: 2026-02-25 20:12:00 UTC

signal show_damage_popup(event_id: StringName, target_unit_id: StringName, damage_amount: int, crit_is_true: bool)
signal show_unit_hit_flash(event_id: StringName, target_unit_id: StringName)


func emit_show_damage_popup(event_id: StringName, target_unit_id: StringName, damage_amount: int, crit_is_true: bool) -> void:
	show_damage_popup.emit(event_id, target_unit_id, damage_amount, crit_is_true)


func emit_show_unit_hit_flash(event_id: StringName, target_unit_id: StringName) -> void:
	show_unit_hit_flash.emit(event_id, target_unit_id)
