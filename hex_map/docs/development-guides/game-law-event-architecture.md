# Game Event Architecture Contract

This contract defines how cross-domain events must flow.

## Purpose

Preserve deterministic gameplay state while allowing rich UI/audio/camera/VFX reactions.

## Non-negotiable constraints

1. Gameplay/state domains are authoritative.
2. UI/audio/camera/VFX domains are non-authoritative.
3. Commands enter authority first, then state commits, then events publish.
4. Presentation events must never mutate gameplay state.
5. Cross-domain fanout occurs in one projection coordinator.
6. Every action chain carries a stable `event_id`.

## Event topology

1. `CombatCommandBus`
- Receives intent commands such as spell-hit requests.

2. `SpellHitResolverExample` (authoritative workflow)
- Validates command.
- Calculates outcome.
- Applies health/state changes via authority callbacks.
- Emits gameplay events through `GameplayEventBus`.

3. `GameplayEventBus`
- Authoritative domain events only:
  - `unit_damaged`
  - `health_changed`
  - `unit_defeated`
  - `spell_resolved`

4. `EventProjectionCoordinator`
- Subscribes to gameplay events.
- Projects to presentation buses:
  - `UIEventBus`
  - `AudioEventBus`
  - `CameraEventBus`
  - `VfxEventBus`

## Spell-hit sequence (reference)

1. `CombatCommandBus.request_apply_spell_hit(event_id, caster, target, spell)`
2. Resolver computes result and commits authority state.
3. Resolver emits on `GameplayEventBus`:
- `unit_damaged(event_id, target, amount, damage_type, crit_is_true)`
- `health_changed(event_id, target, old_health, new_health)`
- optional `unit_defeated(event_id, target, reason)`
- `spell_resolved(event_id, caster, target, spell, outcome)`
4. Projection coordinator fans out to presentation buses:
- UI: hit flash + popup damage
- Audio: hit SFX
- Camera: optional shake
- VFX: impact effect

## Synchronization policy

1. Authoritative sequence is synchronous and deterministic.
2. Presentation handling may be async, but must keep original `event_id`.
3. Consumers should be idempotent per `event_id`.

## Scope note

This contract defines architecture and interfaces. It does not require immediate migration of existing systems in one pass.
