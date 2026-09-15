# Melee lab verification — 2026-09-15

Godot `4.7.2.stable.nixpkgs.ed1daf0bf`, Mobile/Vulkan, NVIDIA RTX 4090.

- `./scripts/test.sh`: all 20 legacy and melee test scripts pass. New focused
  results: physics 19 checks, view 639 checks, integrated lab 39 checks; replay
  codec/interpolation/annotation tests pass. Evidence: `artifacts/melee-suite.log`.
- Physics checks include real blade/slab contact, withdrawal, finite actuator
  effort, reciprocal motor momentum, free-body displacement and pause transitions.
- Integration covers live contact, tracking/handle transitions, replay freezing,
  scrub/export/import, note input and rejection of incompatible clips without
  losing the currently loaded clip. Physics publication may settle across the
  pause boundary; replay is sampled resolved state, not deterministic resimulation.
- Rendered desktop demo and replay inspected at 1280×900:
  `artifacts/melee-cockpit.png`, `melee-replay.png`, `melee-render.log`.
- Isolated OpenXR preflight exits 0 and reaches initialized rendering, seated
  calibration and focused simulated HMD/both-controller tracking:
  `DISPLAY=:0 WAYLAND_DISPLAY=wayland-1 ./scripts/run-monado-qwerty.sh --melee --smoke 180`.
  Evidence: `artifacts/melee-xr.log`, `melee-monado-qwerty.log`.
  It uses a private runtime/socket and null compositor. Shared VR services were
  not restarted. This is not physical headset or full-resolution performance proof.

## Engine/environment diagnostics

The isolated XR run emits shutdown diagnostics: `XR_ERROR_SESSION_NOT_STOPPING`
from `xrEndSession`, nonexistent `spatial_discovery_recommended` signal disconnect,
three InteractionProfile RID allocations and two ObjectDB instances leaked.
Startup/tracking succeeds; clean XR teardown is not established. A durable fix
belongs in the engine/OpenXR shutdown lifecycle or a verified engine update.
No system configuration was changed to work around this.

Headless editor import produced an editor teardown abort at
`editor/editor_node.cpp:6618` (`singleton` null in `is_cmdline_mode`, exit 134).
Imported scenes subsequently run and tests pass. Do not interpret that import
attempt as a clean editor validation. Desktop runtime exits cleanly.

## Deliberate limits

The endpoint model uses authored inertia and finite force budgets, not full joint
constraints, nozzle allocation or validated mech dynamics. CCD/contact tests do
not establish correctness at every possible angular speed. Replay samples visual
poses at 30 Hz, keeps transient contact events and interpolates between poses.
It does not reproduce exact substep collision motion. Export format is a local
prototype format; imports require compatible visual layout. Physics fairness at
100–200 ms network latency remains untested; networking is not implemented here.

Next gate: [actual seated headset comparison](melee-headset-test.md).
