# M0a verification — 2026-09-14

Implementation checkout: `/home/s/.codex/worktrees/3d5e/mech-vr`, branch
`codex/m0a`. The durable project root `/home/s/code/mech-vr` remains the seed
checkout. No push or remote was created. Use `git rev-parse HEAD` to identify
the exact local build; the org checkpoint records the delivered commit.

## Automated evidence

Installed Godot: `4.7.2.stable.nixpkgs.ed1daf0bf`. Renderer: GL Compatibility,
NVIDIA OpenGL 3.3 / RTX 4090 / driver 610.57.04. Physics: 90 Hz.

`./scripts/test.sh` passes **549 checks**:

- 481 motor/ownership checks, including multiple timestep sizes, acceleration,
  brake/no reversal, momentum frame, quaternion rebasing, repeated handoff,
  held inputs, tracking/focus loss and pitch/snap limits.
- 21 finite geometry/range checks: angled shield, swept fast bolts, shield
  before/beside/behind torso, actual muzzle parallax, targets and cadence timing.
- 19 input checks: independent head/hands, native head-pose validity, stale
  control suppression, recovery release edges and desktop/XR separation.
- 28 assembled-scene checks: real panel rows and pointer rays, paused calibration,
  live MFD one-click semantics, stale fire inhibition, muzzle/reticle agreement,
  focus freezing, and physical wall collision without phantom velocity.

Retained logs: `artifacts/{control,range,input,integration}.log`.

Rendered deterministic replay:

```sh
DISPLAY=:0 WAYLAND_DISPLAY=wayland-1 godot4 --path . --xr-mode off \
  --disable-vsync --fixed-fps 90 -- --replay --capture
```

Twelve simulated seconds pass six assertions: brake stops, UI holds, live MFD
changes cadence once, arm reattaches, head motion does not steer, shield blocks.
The replay ended with three blocks and no torso hits. It is an authored
independent-pose replay, not a recording of physical controllers.
`artifacts/replay-no-vsync.log`, `artifacts/replay-run.jsonl`, and
`artifacts/cockpit.png` retain this evidence. A separate 180-frame desktop
paused render is retained as `artifacts/desktop-paused.log`,
`artifacts/desktop-paused-run.jsonl`, and `artifacts/paused-cockpit.png`.
Fixed-FPS replay frame intervals are synthetic and are not performance claims.

## Isolated OpenXR preflight

`DISPLAY=:0 WAYLAND_DISPLAY=wayland-1 ./scripts/run-monado-qwerty.sh --smoke`
uses a private temporary runtime directory/socket and the installed Monado
manifest. It selects QWERTY HMD/controllers, NULL compositor, initializes native
OpenXR, calibrates seated tracking at unit scale, and renders 180 frames.
`MECH_XR_TRACKING_READY` records focused head/both-hand readiness and native
profiles. Retained evidence: `artifacts/openxr-smoke.log`,
`artifacts/monado-qwerty.log`, `artifacts/openxr-run.jsonl`.

The smoke exits zero, but **is not a clean engine shutdown**: stock Godot logs
`XR_ERROR_SESSION_NOT_STOPPING` at `xrEndSession` and GLES texture cleanup/leak
errors. Godot's scripted interface has no session-exit request; local source
inspection shows `uninitialize()` is not a fix for the underlying lifecycle.
No native extension or engine fork was introduced. An upstream Godot OpenXR/GL
teardown fix is preferable to accumulating local shutdown workarounds. A
foveation/subsampled-image warning is also retained. These do not establish a
physical headset rendering failure, but remain explicit engine limitations.

The normal Monado service remained running (PID 3023114, active since
2026-09-14 14:38:27 MDT during verification). Private smoke cleanup stops only
its own child service. No shared runtime restart, NixOS change or original
Industrial Petting Unity-source access occurred.

## Scope and limits

Preset A is runnable. Cockpit/tracking scale is one; external hand displacement
has gain 8, capped servo speed 18 m/s, acceleration 100 m/s² and angular speed
150 degrees/s. Controller orientation is capped at 80 degrees from neutral;
arm displacement is capped within 7 m of its external neutral. The canopy top
to torso bottom spans approximately 18 m. Greybox arms are two visual segments;
there is no anatomical IK/full-mech collision claim. World motion uses a
simplified 3 × 6 × 3 m kinematic box and incoming hits use the same dimensions.

Cruise/boost speeds are 12/30 m/s, acceleration 12/30 m/s², release deceleration
8 m/s², brake 45 m/s². Pitch is capped at ±75 degrees. Default yaw/pitch rates
are 30/20 degrees/s; the paused menu offers 15/10 and 15-degree snap yaw.
Calibration explicitly blends for 0.6 seconds while weapons are inhibited.
Trigger ownership is mutually exclusive and must pass through release on
handoff/recovery. No headset/IPD scale gain or hand-driven body steering exists.

The native adapter/MFD uses the permitted pet-demo input/runner patterns and
Prim SubViewport pattern without importing the complete XR Tools addon. This
bounded deviation and action-map provenance are in `THIRD_PARTY.md`.

The task environment omitted DISPLAY/WAYLAND_DISPLAY; the user service manager
advertised `:0`/`wayland-1`. Forwarding these into Codex task processes is the
durable environment fix. Explicit values were used here. Desktop vsync caused
DRM waits in this session; desktop now disables vsync and caps at 90 FPS, while
XR leaves frame pacing to its runtime. Original failed-run logs are retained
but are superseded by the named successful evidence above.

**Not verified:** physical Beyond/Index binding behavior, stereo scale/comfort,
seated reach, readable headset text, headset-resolution CPU/GPU frame budget,
missed/reprojected frames, or the user's combined-loop preference. QWERTY's
320 × 240 render target is not headset performance evidence. The app reports
Godot viewport CPU/GPU times and frame intervals only, not physical latency.
The first actual user test is `docs/m0a-headset-test.md`; B/C and later gameplay
remain deferred.

## Mirror resize follow-up

The XR mirror now updates its screen attachment when the desktop window size
changes. Godot's XR Window path skips ordinary viewport resizing, which left
this rectangle stale under niri tiling. The adapter polls the actual window
size and only updates the attachment on a change; headset eye resolution stays
runtime-controlled. The stock single-eye mirror preserves aspect with cropping.

Verified with the private QWERTY runtime under niri: destination sizes changed
1905×2123 → 1350×2123 → 2400×2123 while the eye target stayed 320×240.
`artifacts/mirror-resize-smoke.log` retains the changes; the compositor window
capture `artifacts/mirror-900.png` shows the mirror filling the resized client
area. QWERTY's tiny eye target makes that test image pixelated; it is not a
recording-quality or real-headset performance test. All 549 existing checks pass
(`artifacts/mirror-tests.log`). The known engine shutdown messages remain.

## Parked grips and flight puppet follow-up

User reports the previous demo worked and recorded a short video. This is
positive subjective feedback, not a complete physical binding/timing report.

- All 1,358 deterministic checks pass: control 481, range 21, input 19,
  previous integration 28, parked handles 119, flight pose 667, and new combined
  grip/MFD/hologram integration 23 (`artifacts/grip-flight-tests.log`).
- Rendered comparison probe passed with both grips held, left parked at the
  MFD, and right reacquired in calibrated mode. Inspected screenshots
  `artifacts/grip-flight-90.png` and `grip-flight-230.png` show the dashboard,
  separate physical/parked handles and articulated miniature. Render log:
  `artifacts/grip-flight-render.log`. Headless editor import also succeeded.
- Isolated Monado QWERTY startup, seated calibration, focus and both tracked
  controllers passed, exit 0 (`artifacts/grip-flight-xr.log`). Mirror attachment
  followed the tiled window at 1440×2501 with the eye target still 320×240.
  The first attempt lacked display variables; retry used DISPLAY=:0 and the
  absolute Wayland socket because the runner isolates XDG_RUNTIME_DIR.
- The existing stock engine OpenXR session-stop, GLES cleanup and leaked-object
  shutdown messages remain. This is a startup/tracking preflight, not a clean
  engine-teardown result. Normal Monado PID 3023114 was not restarted; no game
  or private runtime remains running after checks.

New Index grip pressure thresholds, parked-handle reach, calibrated-angle
recovery, miniature readability, and flight-pose preference require the next
headset test. The private simple-controller profile does not verify Index
squeeze behavior. Tests establish bounded transforms, fresh-input handoffs and
no hologram writes into gameplay geometry, not comfort or physical realism.
B/C control presets, physical cockpit gimbals and torque simulation are deferred.

## Sparse flight HUD

All 1,358 existing checks pass (`artifacts/hud-tests.log`). Rendered level and
14-degree nose-up frames inspected (`artifacts/hud-level.png`, `hud-pitch.png`;
`hud-render.log` reports HUD_RENDER_OK). Pitch marks move with colony attitude,
while the forward datum stays cockpit-relative. Gun position uses the existing
shared muzzle/shield/obstacle aim query. HUD is real 3D geometry, not a desktop
CanvasLayer. No new native headset validation is claimed: check stereo symbol
placement, size and readability with the normal launch. No shared service changes.

## Shared exterior thrust posture

- All 1,397 checks pass (`artifacts/shared-posture-tests.log`): prior suites
  1,358 plus 39 aggregate shared-pose checks at 30/90 Hz. These verify fixed arm
  lengths and exact equipment connections at legal workspace extremes,
  hologram mesh/hierarchy/transform parity, no procedural movement of camera or
  equipment, thrust decomposition, brief-command rejection, brake retention,
  pause/coast exhaust suppression, idle settling and cross-rate agreement.
- Added actual main-loop hit/miss checks at the animated chest and the obsolete
  upright body origin. The chest hurtbox follows visible geometry; the separate
  navigation hull is deliberately unchanged. Found/fixed a 2 cm IK endpoint gap
  for coincident shoulder/wrist positions.
- Rendered idle, thrust, brake, strafe and cockpit views retained in
  `artifacts/shared-*.png`; thrust/cockpit inspected. Log:
  `artifacts/shared-posture-render.log` reports SHARED_POSTURE_RENDER_OK.
- Rendered combined replay passes all six checks, including shield blocks and
  independent head motion (`artifacts/shared-posture-replay.log`).
- Isolated QWERTY OpenXR startup, seat calibration, focus and both controllers
  pass, exit 0 (`artifacts/shared-posture-xr.log`). Known stock engine teardown
  warnings remain; no shared service restart. This does not establish physical
  Index inputs, headset performance or visual comfort.

The new body proportions, shoulder travel, timing, hologram framing and shield
coverage during posture changes need headset judgment. No full limb collision,
self-contact solver, camera/robot-head coupling or physical thrust/torque claim.

## Visual sword and Mobile art pass

- 1,504 automated checks pass (`artifacts/art-tests.log`): previous 1,397,
  weapon module 39, actual weapon integration 34, exhaust/wake 34.
  Actual-scene checks cover physical dock vs amplified hand, swaps without
  shooting, fresh firing after return, hologram visibility, grip/UI/pause/
  tracking/calibrated handoff, reset and zero sword damage. Exhaust checks
  cover bounded history, world anchoring, fade, teleport/reset, pause/coast,
  light suppression and boost-only cosmetic output without fabricated force.
- Mobile/Vulkan rendered six-check replay passes (`artifacts/art-replay.log`).
  Existing wall collision test still passes against the smaller backstop.
- Art probe (`artifacts/art-render.log`) reports ART_RENDER_OK, sword=true,
  renderer=mobile. Inspected cockpit captures in `artifacts/art-cockpit-*.png`;
  `art-exterior.png` retains an outside view. These include the actual shared
  scene in a 1600×1000 review viewport, not a generated illustration.
- Isolated QWERTY OpenXR on Mobile/Vulkan initializes, calibrates and tracks both
  controllers (`artifacts/art-xr-final.log`). Mirror attaches to tiled window
  extent while runtime controls eye size. Stock session-stop/spatial-extension
  teardown diagnostics remain; no shared Monado restart was performed.
- Starfield license/source/hash recorded in `assets/sky/SOURCE.md` and
  `THIRD_PARTY.md`. No franchise assets or publication.

Physical behind-head Index tracking/reach, stereo visual quality and full
Beyond-resolution frame pacing require the next user check. The small private
OpenXR render target does not establish headset performance. Sword collision,
physical plume forces and distant-colony traversal remain out of scope.
# Final sky orientation check

`artifacts/art-sun.png` and `artifacts/art-sun.log` verify the upward-looking
Mobile render after correcting the source skybox pole orientations. Source PNGs
remain unchanged; top/bottom faces rotate at runtime. No script/render errors.


## Hybrid pilot controls, range combat and optic

- 1,638 checks pass (`artifacts/hybrid-tests.log`): previous 1,504, range gains
  one arrival check, pilot 40, actual pilot integration 20, rifle/scope 24,
  combat 23, actual combat integration 26. The final combat integration log is
  appended from its independently executed actual-scene run. The test runner
  includes every suite for one-command reproduction.
- Actual-scene tests cover pilot/arm exclusivity, fresh-grip recovery, other-arm
  independence, cruise while both arms are held, head-independent direction,
  brake closing the throttle without relaunch, roll retention, pause/reset,
  scope near/rest/release/sword/pilot gates, actual barrel origin and delayed
  pulse impact, servo-driven sword contact/debounce and inactive sweep reset.
- Desktop Mobile/Vulkan replay passes all six checks (`hybrid-replay.log`).
  `hybrid-render.log` reports 9 targets, 5 arrived rifle hits and sustained cruise
  at 84.5 m/s during the ramp. Inspected `hybrid-cockpit.png`, `hybrid-scope.png`,
  `hybrid-optic.png`, `hybrid-cruise.png`, `hybrid-exterior.png`. These are actual
  scene captures. The second render corrects muzzle-pulse optic occlusion, scope
  exit hysteresis, center-stick dashboard clearance and crowded contact labels.
- Headless editor import passes (`hybrid-import.log`); diff whitespace check passes.
- **Current XR preflight blocked by GPU state.** `hybrid-xr.log` fails before
  scene startup with Vulkan error -3; `hybrid-xr-retry.log` also fails to create
  Vulkan devices. At 21:03:27 MDT, the kernel records NVIDIA Xid 51 on the existing
  normal Monado PID 3023114, Xid 154 recovery action PF FLR, then
  `NV_ERR_RESET_REQUIRED`. Evidence: `hybrid-gpu-kernel.log`. This does not
  establish a cause for the GPU fault. No shared service restart, GPU reset or
  system change was attempted. Recover the host GPU (a user-timed reboot is
  the straightforward route), then rerun isolated XR and the headset card.

Tuning: center translation travel 20 cm, angular travel 0.55 rad, rate 35 deg/s pitch
and 45 deg/s yaw/roll; release commands zero with existing motor deceleration.
Main throttle is robot-forward 90 m/s max, ramped command, brake 45 m/s² and throttle
OFF on brake/pause/lost left tracking. Scope 512² with 4x optics relative to 75 deg,
enter 42 cm / exit 50 cm. Player pulse 240 m/s, range 2,600 m; first 12 m excluded from optic
only. Nine bots, four moving; three outer emitters activate within 260 m. Sword
contacts and sparks have no health, destruction, blade resistance or force sim.
The colony remains decorative, with existing local obstacles providing collision.
Physical reach, six-axis comfort, scope stereo usability and full-resolution
performance remain user checks, especially while the extra optic camera renders.
