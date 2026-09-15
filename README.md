# Mech VR — M0a

Runnable seated PCVR cockpit experiment in Godot 4.7.2, Mobile / Vulkan.
Preset A only: cockpit-relative flight, independent tracked rifle/shield,
finite incoming bolts, explicit arm/UI handoff, and a live cadence MFD.

```sh
# From this checkout, using the installed Godot engine:
./scripts/run.sh                 # desktop, starts paused
./scripts/run.sh --xr            # native OpenXR, starts paused
./scripts/test.sh                # 1,638 deterministic / actual-scene checks
./scripts/run-monado-qwerty.sh --smoke  # private simulated runtime
```

The task process on sayu lacked display variables. When launching from that
context, prefix rendered commands with `DISPLAY=:0 WAYLAND_DISPLAY=wayland-1`.
A normal graphical terminal usually already has them. Never point the private
smoke at the user's runtime socket or restart their VR services.

Hold the right grip, reach behind your head and press/release the trigger to
switch rifle ↔ beam sword. Repeat the dock gesture to switch back.
Swept sword contacts and traveling rifle pulses produce hit confirmations;
targets have no health/destruction state. A HUD cue identifies the dock and weapon.
The art pass adds a CC0 starfield, exterior cylinder backdrop, warm sunlight,
HDR glow, seven verniers, local exhaust lighting and a short world-space wake.

**Next check: [hybrid flight and combat headset check](docs/m0a-headset-test.md).**
Initial user feedback and the reattachment tradeoff are in
[playtest notes](docs/playtest-notes.md).
Read [verification and limits](docs/verification.md) for actual evidence. No
complete physical timing/binding validation or A/B/C preference result is claimed.

Default control: hold grip near a cockpit handle to grab it; release to park
the handle and robot arm while reaching for UI. The live MFD compares FREE and
CALIBRATED ANGLE regrabs, the previous B-button mode, and THRUST/UPRIGHT shared body posture.

The cyan center stick accepts either free hand: squeeze grip, displace for XYZ
velocity, tilt/twist for pitch/yaw/roll rates, then release to center. Its home
is lower than the arm handles so it clears the dashboard. The amber left throttle
slides forward for persistent robot-forward cruise, up to 90 m/s with a ramp.
Release and regrab the arm handle to use shield and rifle during cruise. Pull
back to OFF; the brake button also closes the throttle and prevents relaunch.
Head movement never steers cruise. Pause or lost left tracking closes throttle.

Bring the held right gun controller within roughly 42 cm of the head for the
4x circular scope; lower it past 50 cm to hide it. Only the visible scope renders
its 512² extra camera. Nine target bots include four moving contacts, spread to
about 1.8 km; rifle pulses travel at 240 m/s and need lead. The three outer
emitters wake within 260 m. Sword contacts, target hits and shield blocks give
short bursts without health, destruction or physical blade resistance.

The exterior and hologram share one rig; [space-body posture notes](docs/research/space-body-posture.md)
cover the Echo/Space Junkies references. See [UNDERDOGS research](docs/research/underdogs-controls.md) for design references.

Desktop: hold G/H for left/right grip. WASD translation, Q/E descend/ascend, arrows yaw and vertical/pitch,
Tab switches the right-stick Y function, Shift boost, Space brake, left mouse
fire. In legacy B-button mode, Z/X toggles left/right arm UI; Shift/left mouse clicks when that hand owns
UI. 1/2/3 selects head/left/right pose. Right-mouse drag rotates only that pose;
Ctrl+right-drag moves XY and Alt+right-drag moves depth. Esc pauses, R resets
while paused, F6/F7 simulates hand tracking loss, F8 retains the last 30 seconds
of input/arm/velocity samples. Point a hand ray at the MFD to click it.

The console offers seated reset, resume, lower turn rates, and snap yaw while
paused. Preferences are local in Godot's `user://m0a.cfg`; startup logs record
active arm/turn parameters. Movement tuning is in `scripts/control_model.gd`.
Run/issue logs and screenshots are in ignored `artifacts/`; no media or caches
are committed. See [provenance](THIRD_PARTY.md) for permitted reference reuse.

The approved [MVP plan](docs/mvp-plan.md) and
[implementation brief](docs/IMPLEMENTATION_BRIEF.md) define the scope. B/C,
full melee physics, torque simulation, networking, tutorial and publication await later gates.
The subsequent user-authorized experiments add parked controls, shared posture,
visual art, six-axis rate flight, throttle, traveling shots, sword hit feedback and scope.
