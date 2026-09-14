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
