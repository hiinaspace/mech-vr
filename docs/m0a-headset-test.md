# M0a first seated headset gate — not yet run

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
2. **Resume and bindings:** click RESUME or click the right thumbstick. Left
   stick strafes/forwards; right stick X yaws; right stick Y ascends/descends.
   Right A changes Y to pitch; center the stick before it activates. Left
   trigger boosts and left A (the X-equivalent) brakes. Release-to-slow is on.
   Look aside while moving; only deliberate stick input may rotate the cockpit.
3. **Independent combat:** right trigger fires from the visible muzzle. Aim at
   a target while looking elsewhere, then strafe and brake. Place the left
   shield across the bright incoming bolt path; move it aside once. Check
   actual reticle/impact agreement and BLOCK versus HIT counts. The shield is
   a finite 4 × 6 m slab, not a shield-up flag.
4. **Live MFD:** right B (or left B/Y-equivalent) holds that robot arm and gives
   that hand UI ownership. Release the trigger, aim at the MFD, then click to
   change cadence. The other arm stays live. B returns to arm control without
   a snap; release the trigger before firing/boosting again. Brake remains
   available while the left hand owns UI. Repeat three times.
5. **Pause and report:** right stick click pauses. Record any wrong binding,
   uncomfortable scale/reach, unreadable text, unintended fire/thrust, arm
   snap, or frame hitch. A keyboard helper can press F8 to save the preceding
   trace. Stop whenever the controls or comfort make continuation unhelpful.

Index labels differ from the draft X/Y notation: each controller physically
has A/B. Left A = brake, left B = left UI; right A = vertical/pitch mode,
right B = right UI. Right thumbstick click is the pause fallback because the
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
