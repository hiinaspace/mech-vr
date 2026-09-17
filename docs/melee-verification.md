# Persistent heat trails and cockpit mapping

## Changes and cause

The parked-arm drift was a feedback error: each ungrabbed frame called the legacy
model's hold function, copying its lagging physical arm pose into the next target.
During sustained acceleration, that repeatedly moved the goal. Melee now uses an
independent robot-local arm mapping whose commanded targets latch when released.
Physical pose feedback is used for indicators/ownership, never as a repeated arm
target update. A fixed robot-head offset maps between cockpit and robot references.
Neither body world pose nor HMD translation participates in the arm mapping.

Physical thumbstick translation continuously uses current head rotation, and pitch
uses head-right; yaw stays robot-local upright. The virtual six-axis stick remains
cockpit-relative. Calibration clutches the target while trigger is held and saves
translation/orientation offsets per arm only on explicit Finish. Reset/Cancel
semantics preserve the original mapping until saved. Flight/boost are inhibited
while calibrating; arm simulation continues. Automated tests use isolated configs.

Heat blits now use additive texture blending. Persistent 16×16 cells on each of
six faces replace the eight-stamp queue; cells retire only after cooling below
threshold. Exponential cooling has a 1.73-second half-life. An independent hidden
geometry rig resolves all solid armor/limb/hilt surfaces from authoritative poses;
local displayed pose delay cannot move the queried surface. These visual surfaces
do not add rigid-body limb masses or physical joint constraints.

## Evidence

- All 28 test scripts pass: `artifacts/melee-trails-mapping-suite.log`. New mapping
  unit tests: 15, head-frame tests: 5, pilot tests: 50, actual arm integration: 23 in the
  suite. The final Reset→Cancel regression brings arm integration to 24 in
  `artifacts/melee-arm-integration-final.log`. Existing lifecycle: 39, core: 45 and
  authority/beam integration: 182 remain passing.
- Actual-scene tests cover sustained throttle with released shield, HMD translation,
  regrab under actuator error, calibration clutch/save/reset/load and cockpit-error
  replay. Head-frame tests distinguish real thumbsticks from the virtual stick.
- GPU readback verifies two overlapping .3 heat stamps add above .55 instead of
  replacing each other. Rendered scripted sweep diagnostics retain 14 shield and 21
  shin cells after beam contact ends, with exactly half the total heat after 1.73 s.
  Inspected `artifacts/melee-shield-trail.png`, `melee-limb-trail.png` and
  `melee-limb-trail-half-life.png`; log `melee-trail-render.log`.
- Rendered cockpit/replay and calibration panel inspected. Logs:
  `artifacts/melee-mapping-render.log`, `melee-calibration-render.log`; captures
  `melee-cockpit.png`, `melee-replay.png`, `melee-calibration.png`.
- Isolated XR reaches startup, recentering and both-controller focused tracking:
  `artifacts/melee-trails-mapping-xr.log`. Existing shutdown diagnostics remain;
  rendered lab exits can also show the previously identified audio-object leaks.
  No shared service or system configuration changes. No new physical headset,
  full-resolution performance, comfort or subjective calibration claims.

## Limits

The per-face heat cells and primitive-box surface projection approximate painting;
this is not continuous volumetric cutting or thermal damage. Active painted atlases
still rebuild from their compact cell history. Dense sustained painting across many
parts can cost more CPU/GPU work and replay space; actual headset performance is a
remaining user gate. Unchanged/empty paint states skip redundant texture work.

A 20-second real-scene-schema replay with 100 heat cells exports/imports at 29,164,680
bytes. Export/import remains bounded at 32 MiB; arbitrary paint density is not a
promise of a successful full 20-second export. The live pose recorder still retains
20 seconds. Arm endpoint mechanics still lack physical limb/joint reach constraints;
command stability does not make an underpowered actuator keep up with any thrust.

See [the test card](melee-headset-test.md) for F3 calibration and input/error cues.

---

# Beam absorption and lighting pass

- Sabers physically collide only with other sabers. An independent full-length
  beam/box query selects the first opposing armor surface from the hilt; both
  rendered and physical beam length end there. Armor itself gives no saber impact
  impulse. The query still runs while shortened, preserving stationary dwell.
- Visual heat now deposits 2.5 units/second during overlap, without an initial
  hit bonus. Duplicate contact records cannot multiply a saber's per-tick budget.
  Hot patches stay attached to the surface and cool as before. No damage is added.
- Overhead slash raised/lowered targets moved from local X=-5 to X=+5, matching
  the sword/right shoulder. Existing live-speed phase continuity remains intact.
- Added one offset suit-mounted spotlight with shadows for directional shape
  cues. It follows delivered/recorded suit poses. Original range lighting and
  renderer settings remain unchanged.

## Evidence

All 25 test scripts pass in `artifacts/melee-beam-suite.log`, including 45 physical
checks, 182 authority/movement/beam integration checks and 39 lifecycle checks.
Actual-world tests establish nonblocking shield absorption without solver impulse,
continued heat while shortened, nearest-of-multiple-surface selection, restored
length on withdrawal, and no invisible blade clash behind the plate. Exposed
beam clashes still transfer force. Appearance tests compare short-swipe deposited
heat at 60/120 Hz, exact short dwell, clipping and replay/live restoration.
Replay export/import preserves clipped visuals, overlap metadata and heat.

Rendered cockpit/replay captures in `artifacts/melee-cockpit.png` and
`melee-replay.png` were inspected; `melee-beam-render.log` exits cleanly. Isolated
XR evidence is in `artifacts/melee-beam-xr.log`; startup/tracking succeeds with
the previously documented engine shutdown diagnostics. This does not establish
headset comfort, full-resolution frame timing or feel of the revised contacts.

The simplified armor is still torso/shield boxes; own armor is ignored. Queries
sample a zero-width centerline each physics tick, so grazing contacts and very
fast sub-tick crossings are not continuous volumetric burn simulation. Shape
length follows the solver update cadence. No new health, ablation or heat-transfer
model is implied. The slab clips beams but is not part of the painted robot atlas.
See [the test card](melee-headset-test.md) for the new comparisons.

---

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
