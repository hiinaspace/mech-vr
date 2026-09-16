# Melee tuning pass — 2026-09-16

User feedback described arm forces/compensators as promising and authorized this
live tuning, simulated-lag, movement and readability pass. Actual headset judgment
of the revised controls/materials remains the next gate.

## Current evidence

- All 25 test scripts pass: the 24-script suite in
  `artifacts/melee-tuning-suite.log`, plus the subsequently added 10-check ray/drag
  panel test in `artifacts/melee-panel.log`. The runner now includes all 25.
- Physics: 42 checks after the final live-speed continuity fix, including broad
  overhead slash geometry, finite high-strength actuation and player-only boost.
  Speed edits preserve the active slash phase instead of jumping the target.
  The earlier full-suite log contains the preceding 35-check physics version. Paired pose view: 639 checks.
- Integrated authority/movement: 170 checks prove half-RTT command arrival and
  half-RTT committed return, delayed cockpit orientation/translation, live tuning,
  pause/replay flushing, physical six-axis stick, boost and brake priority.
- Delay helper: 18 checks. Existing integrated replay lab: 39 checks. Dedicated
  overlap test verifies the movable arm handle wins a fresh acquisition over the
  resettable stick. Original ranged scene uses that same fix.
- Appearance tests verify heat attachment/fade, replay roundtrip/validation and
  independent arm colors. Real Vulkan GPU readback verifies hot atlas pixels,
  an unaffected opposite face and cooling. Evidence:
  `artifacts/melee-appearance-render.log`, `melee-appearance.png`.
- Final rendered contact/replay views inspected in `artifacts/melee-cockpit.png`
  and `melee-replay.png`; lower tilted slider panel inspected in `melee-tuning.png`.
  Render logs: `melee-tuning-render.log`, `melee-tuning-panel.log`.
- Isolated XR command below exits 0 and reaches focused simulated headset/both
  controller tracking. Same stock shutdown diagnostics persist (session not
  stopping, disconnect and three InteractionProfile RIDs). Evidence:
  `artifacts/melee-tuning-xr.log`. No shared service or NixOS configuration changes.

```sh
DISPLAY=:0 WAYLAND_DISPLAY=wayland-1 ./scripts/run-monado-qwerty.sh --melee --smoke 180
```

## Model and rendering limits

The lag harness transports already-mapped desired poses/velocity/attitude. Physics
and its finite actuator loops run authoritatively; render poses use only returned
snapshots. Local head/hand tracking, cockpit controls and control-intent mapping
remain immediate. It is fixed symmetric latency, with no prediction, jitter,
packet loss, real server scheduling or adversarial remote inputs. Physics tick
sampling adds a small delay beyond the chosen RTT. Tuning values are immediate
operator settings. RTT changes flush both queues and reseed parked commands plus
the previous displayed state, so dragging ping can briefly hold the view.

Heat uses Godot 4.7's [DrawableTexture2D](https://docs.godotengine.org/en/4.7/classes/class_drawabletexture2d.html)
to paint a small six-face atlas, restored from up to eight compact marks per
surface. Marks shrink near face seams rather than spilling into another face.
Only body/shield contact paints heat; blades do not burn each other. This is
visual feedback with fading, not heat transfer, material loss or damage. Puppet
arm colors indicate normalized motor effort (force/torque versus current limits),
not an absolute force scale. Limb geometry remains visual IK.

Some rendered lab exits report four leaked audio objects: verbose inspection
identifies two AudioStreamWAV and two AudioStreamPlaybackWAV references, not the
Drawable textures. The standalone painted-material render exits cleanly. Audio
shutdown ownership needs a focused engine/application lifecycle fix; no global
runtime workaround was introduced. The older editor/XR diagnostics below remain
separate from successful runtime tests.

See [the revised test card](melee-headset-test.md) for controls and comparisons.

---

## Previous contact lab verification — 2026-09-15

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
