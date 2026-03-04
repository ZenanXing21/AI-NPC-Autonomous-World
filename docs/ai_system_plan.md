# NPC AI System Plan (Godot 4)

This plan proposes a modular AI architecture for NPCs using:
- **NavigationAgent3D** for local path-following and movement steering.
- **NavigationRegion3D / NavigationMesh** for global walkable areas.
- Optional **Behavior Tree** integration (GodotBT or Beehave) for high-level decisions.

## 1) Core Design Goals
- Keep movement/pathfinding independent from decision logic.
- Support both simple FSM-driven NPCs and BT-driven NPCs.
- Make perception reusable (sight/hearing checks can feed any brain).
- Use data-driven resources for tuning behavior without rewriting scripts.

## 2) Proposed Folder/File Layout

### `scripts/ai/core/`
- `ai_context.gd`
  - Shared runtime state for one NPC (target, blackboard-like values, references).
- `ai_blackboard.gd`
  - Key-value memory with typed helper methods.
- `ai_brain_base.gd`
  - Interface/base class for any decision system (`tick`, `set_context`, `reset`).
- `ai_state_machine.gd`
  - Lightweight FSM runtime for projects not using BT.
- `ai_debug_draw.gd`
  - Optional debug rendering for paths, senses, and state labels.

### `scripts/ai/navigation/`
- `nav_agent_controller.gd`
  - Wraps `NavigationAgent3D`; exposes `set_destination()`, `stop()`, `get_next_velocity()`.
- `nav_path_monitor.gd`
  - Tracks stuck detection, repath timer, destination tolerance checks.
- `nav_avoidance_profile.gd`
  - Resource for avoidance/max speed/acceleration settings.

### `scripts/ai/perception/`
- `perception_system.gd`
  - Central perception tick; publishes visible/heard stimuli.
- `sight_sensor.gd`
  - FOV, distance, line-of-sight checks (`PhysicsRayQueryParameters3D`).
- `hearing_sensor.gd`
  - Handles noise events with falloff and priority.
- `stimulus_event.gd`
  - Data object/resource for perceived events (position, source, threat level, timestamp).

### `scripts/ai/decision/fsm/` (fallback or simple NPCs)
- `npc_state_idle.gd`
- `npc_state_patrol.gd`
- `npc_state_investigate.gd`
- `npc_state_chase.gd`
- `npc_state_flee.gd`

### `scripts/ai/decision/bt/` (optional behavior tree)
- `bt_adapter.gd`
  - Bridge between game context and chosen BT plugin.
- `bt_blackboard_sync.gd`
  - Synchronizes AI blackboard ↔ BT blackboard keys.
- `tasks/`
  - `task_move_to_target.gd`
  - `task_patrol_route.gd`
  - `task_look_at_target.gd`
  - `task_wait.gd`
- `conditions/`
  - `cond_can_see_target.gd`
  - `cond_target_in_range.gd`
  - `cond_has_last_known_position.gd`

### `scripts/ai/combat/`
- `combat_controller.gd`
  - Attack timing, cooldowns, range checks.
- `threat_evaluator.gd`
  - Scores targets and chooses best target.

### `scripts/ai/data/` (Resources)
- `npc_ai_profile.gd`
  - Resource containing tuning values (speeds, vision range, aggression, etc.).
- `patrol_route_resource.gd`
  - Patrol points and route mode (loop/ping-pong/random).
- `faction_matrix_resource.gd`
  - Friend/foe relationship lookup.

### `scripts/npc/`
- `npc_actor.gd`
  - Top-level orchestrator attached to NPC root; wires movement, perception, and brain.
- `npc_motor.gd`
  - Applies movement velocity to `CharacterBody3D` and animation parameters.
- `npc_animation_bridge.gd`
  - Converts AI/motion state into animation tree parameters.

### `scenes/npc/`
- `npc_base.tscn`
  - Reusable NPC scene with child nodes:
    - `NavigationAgent3D`
    - Sensor nodes (Area3D, RayCast3D helpers as needed)
    - Animation tree/player
- `components/perception_sensor.tscn`
  - Optional reusable perception component scene.

## 3) Integration With Existing `npc_controller.gd`
1. Keep `scripts/npc_controller.gd` as a compatibility wrapper initially.
2. Move movement/path code into `scripts/ai/navigation/nav_agent_controller.gd`.
3. Gradually replace direct decision code with `npc_actor.gd` + FSM/BT brain.
4. After migration, either:
   - keep `npc_controller.gd` forwarding to new APIs, or
   - rename/deprecate it and update scene references.

## 4) Behavior Tree Plugin Strategy (Optional)
- Add adapter layer (`bt_adapter.gd`) so game code does not depend on one plugin API.
- Support both by implementing small adapters:
  - `bt_adapter_godotbt.gd`
  - `bt_adapter_beehave.gd`
- Keep shared tasks/conditions thin and data-driven via `ai_context` + blackboard keys.

## 5) Suggested Blackboard Keys
- `target_actor`
- `target_position`
- `last_known_target_position`
- `has_line_of_sight`
- `alert_level`
- `current_patrol_index`
- `home_position`
- `is_in_combat`

## 6) Development Phases
1. **Foundation**
   - `ai_context`, `ai_blackboard`, `npc_actor`, `nav_agent_controller`.
2. **Perception**
   - `sight_sensor`, `hearing_sensor`, `perception_system` + debug visualization.
3. **Decision Layer**
   - FSM states for idle/patrol/investigate/chase.
4. **Combat + Threat**
   - Target scoring, chase/attack transitions.
5. **Behavior Tree Option**
   - Add BT adapter and migrate complex NPC archetypes.
6. **Polish**
   - Profiling, LOD AI tick rates, debug tools, designer-tunable resources.

## 7) Minimal First Milestone (Recommended)
Implement these first files to get an end-to-end working NPC:
- `scripts/npc/npc_actor.gd`
- `scripts/ai/core/ai_context.gd`
- `scripts/ai/core/ai_blackboard.gd`
- `scripts/ai/navigation/nav_agent_controller.gd`
- `scripts/ai/perception/sight_sensor.gd`
- `scripts/ai/decision/fsm/npc_state_patrol.gd`
- `scripts/ai/decision/fsm/npc_state_chase.gd`
- `scenes/npc/npc_base.tscn`

This milestone supports patrol + chase with navigation and LOS-based detection, which is enough to validate the architecture before adding BT and combat complexity.
