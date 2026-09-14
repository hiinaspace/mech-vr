# M0a seated headset test

Initial user feedback is positive; see [playtest notes](playtest-notes.md).
The dashboard, parked grip controls, and flight-pose miniature are ready for comparison.

Use sayu's normal Beyond/Index VR setup. No shared service restart is part of
this handoff. Sit facing forward with controllers in a comfortable neutral
position before launch. The first valid tracked head pose calibrates the seat
at 1 metre per metre; simulation starts paused.

Exact launch for this implementation checkout:

```sh
DISPLAY=:0 WAYLAND_DISPLAY=wayland-1 \
XR_RUNTIME_JSON=/run/current-system/sw/share/openxr/1/openxr_monado.json \
/home/s/.codex/worktrees/3d5e/mech-vr/scripts/run.sh --xr
```

1. **Scale and tracking:** check the seat, armrests, canopy, both controller
   markers and external arms. Point either hand at RESET / SEATED CALIBRATE and
   use a fresh trigger press if the seat needs correction. Reset blends arms
   for 0.6 seconds with gameplay inhibited. Check the console is readable.
2. **Resume and bindings:** click RESUME or click the right thumbstick. Release
   grip, reach near each visible handle (within 12 cm; it highlights green),
   then squeeze to acquire it. Keep gripping while controlling that arm. Left
   stick strafes/forwards; right stick X yaws; right stick Y ascends/descends.
   Right A changes Y to pitch; center the stick before it activates. Left
   trigger boosts and left A (the X-equivalent) brakes. Release-to-slow is on.
   Look aside while moving; only deliberate stick input may rotate the cockpit.
3. **Independent combat:** right trigger fires from the visible muzzle. Aim at
   a target while looking elsewhere, then strafe and brake. Place the left
   shield across the bright incoming bolt path; move it aside once. Check
   actual reticle/impact agreement and BLOCK versus HIT counts. The shield is
   a finite 4 × 6 m slab, not a shield-up flag.
4. **Park and compare:** release grip. The cockpit handle and actual arm stay
   parked while the physical hand can move away and point at the MFD. Release
   trigger before clicking. Regrab near the parked handle with a fresh squeeze.
   Try holding the shield near the face, then freeing the hand. Compare the
   live REGRAB row: FREE preserves the current robot angle on reacquisition;
   CALIBRATED ANGLE keeps position rebasing but gradually aligns to the physical
   controller's cockpit-relative orientation. Fire/boost stays inhibited until
   alignment and a real trigger release. Switching modes parks both handles.
   The CONTROL row restores the previous B-button arm/UI toggle if desired.
   Detached hands cannot command their sticks; left A brake remains available.
5. **Flight puppet:** use the HOLOGRAM row to compare FLIGHT PREVIEW with the
   original ACTUAL RIG. Accelerate, boost, strafe and brake: the preview spine
   leans toward commanded acceleration, with backpack exhaust plus residual
   vernier exhaust. During coast, jets extinguish while the body can retain a
   velocity-aligned pose. Watch shoulder/elbow reach and readability. Red wrist
   markers indicate targets beyond the preview arm's reach. This only animates
   the miniature: cockpit, real weapons, shield and collision stay unchanged.
6. **Pause and report:** right stick click pauses. Record any wrong binding,
   uncomfortable scale/reach, unreadable text, unintended fire/thrust, arm
   snap, or frame hitch. A keyboard helper can press F8 to save the preceding
   trace. Stop whenever the controls or comfort make continuation unhelpful.

Index labels differ from the draft X/Y notation: each controller physically
has A/B. Left A = brake; right A = vertical/pitch mode. In legacy mode,
left B = left UI and right B = right UI. Right thumbstick click is the pause fallback because the
system menu button may be reserved by the runtime.

Record build HEAD, headset refresh/resolution, seating/neutral pose and result.
`artifacts/headset-engine.log` retains engine output;
`artifacts/latest-run.jsonl` has ownership/fire/counter events and a closing
Godot render CPU/GPU timing summary. F8 writes `artifacts/issue-*.json` with
head/hands, actual/desired arms, velocity and brake/boost state. Preserve these
files before the next launch overwrites the latest log. The app cannot currently
report compositor missed/reprojected frames: obtain those from the normal
runtime tooling if available. A zero timing value can mean unsupported.

Next action is this user test, then a bounded fix if needed. Do not proceed to
B/C comparison presets before scale, bindings and the basic loop are checked.
