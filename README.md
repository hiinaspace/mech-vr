# Mech VR — M0a

Runnable seated PCVR cockpit experiment in Godot 4.7.2, GL Compatibility.
Preset A only: cockpit-relative flight, independent tracked rifle/shield,
finite incoming bolts, explicit arm/UI handoff, and a live cadence MFD.

```sh
# From this checkout, using the installed Godot engine:
./scripts/run.sh                 # desktop, starts paused
./scripts/run.sh --xr            # native OpenXR, starts paused
./scripts/test.sh                # 549 deterministic checks
./scripts/run-monado-qwerty.sh --smoke  # private simulated runtime
```

The task process on sayu lacked display variables. When launching from that
context, prefix rendered commands with `DISPLAY=:0 WAYLAND_DISPLAY=wayland-1`.
A normal graphical terminal usually already has them. Never point the private
smoke at the user's runtime socket or restart their VR services.

**Next gate: [short seated headset test](docs/m0a-headset-test.md).**
Read [verification and limits](docs/verification.md) for actual evidence. No
physical headset validation or A/B/C preference result is claimed.

Desktop: WASD translation, Q/E descend/ascend, arrows yaw and vertical/pitch,
Tab switches the right-stick Y function, Shift boost, Space brake, left mouse
fire. Z/X toggles left/right arm UI; Shift/left mouse clicks when that hand owns
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
saber, roll/torque, networking, tutorial and publication await later gates.
