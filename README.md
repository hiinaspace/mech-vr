# Mech VR — greybox demo

This is an editable Godot source project for a seated PCVR greybox: a small
flyaround/ranged cockpit experiment and a separate melee contact lab. It is
not a finished game, SDK, multiplayer demo, or distributable build. Open the
repository in Godot 4.7.2, or use the launch scripts below.

## Try it

Run commands from the repository root:

```sh
# Flyaround / ranged cockpit scene (main.tscn)
./scripts/run.sh                 # desktop, starts paused
./scripts/run.sh --xr             # native OpenXR, starts paused

# Melee testing / contact lab (melee.tscn)
./scripts/run-melee.sh            # desktop
./scripts/run-melee.sh --xr       # native OpenXR

# Automated source checks and isolated, non-headset OpenXR smoke
./scripts/test.sh
./scripts/run-monado-qwerty.sh --smoke
./scripts/run-monado-qwerty.sh --melee --smoke
```

The scripts expect `godot4`; native XR additionally needs a working OpenXR
runtime and tracked controllers. The Monado commands create a temporary
private runtime and null compositor; they do not use or restart a normal VR
session. If a rendered command has no display environment, prefix it with
`DISPLAY=:0 WAYLAND_DISPLAY=wayland-1` on this machine. The same project can
also be imported in the Godot editor and opened via `main.tscn` or `melee.tscn`.

### Flyaround controls

The desktop adapter is useful for trying the cockpit loop without a headset:

| Action | Desktop | XR |
| --- | --- | --- |
| Translate | `WASD`, `Q/E` | Left stick / cockpit stick |
| Yaw and vertical/pitch mode | Arrow keys, `Tab` switches mode | Right stick; face button switches Y |
| Boost / brake | `Shift` / `Space` | Left trigger / brake button |
| Grab left/right arm | Hold `G` / `H` | Grip the matching cockpit handle |
| Fire / UI click | Left mouse | Right trigger while that hand owns UI |
| Pause / reset | `Esc` / `R` | Stick click / panel reset |
| Pose diagnostics | `1/2/3`, right-mouse drag | Tracked head/hand poses |

The scene starts paused. Use the cockpit panel for arm ownership and live
tuning. The [M0a headset test](docs/m0a-headset-test.md) and [verification and
limits](docs/verification.md) describe the intended checks and what has not
been validated.

### Melee testing controls

The melee lab starts paused. Grip the cyan center stick or the arm handles to
fly and command the robot arms; release a grip to operate the panel. On
desktop, `G/H` hold the left/right grips, `Shift` is the left trigger, `Space`
brakes, and the mouse aims (`LMB` fires, `RMB` rotates the selected pose).
Use `F2` for force/speed/lag tuning, `F3` for arm calibration, `M` to cycle
guard/repeated-cut/slab scenarios, `F` to toggle fixed/free opponent, `T` for
the 20-second replay, and `F5` to export a replay with notes. The panel shows
the current controls in XR.

Start with the [melee headset test card](docs/melee-headset-test.md), then see
[melee verification](docs/melee-verification.md) and the
[melee greybox research](docs/melee-greybox-research.md). Those documents
separate automated/desktop evidence from the remaining physical headset gate.

## Original ranged MVP

Runnable seated PCVR cockpit experiment in Godot 4.7.2, Mobile / Vulkan.
Preset A only: cockpit-relative flight, independent tracked rifle/shield,
finite incoming bolts, explicit arm/UI handoff, and a live cadence MFD.

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

**Ranged MVP accepted; melee contact lab is ready for its first headset test.**
No subjective headset result is claimed here. Third-party asset terms are
recorded separately in [THIRD_PARTY.md](THIRD_PARTY.md), and this source repo
is released under the [WTFPL](LICENSE).
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
[implementation brief](docs/IMPLEMENTATION_BRIEF.md) define the scope. The
[playtest notes](docs/playtest-notes.md) record design context; B/C, full melee
physics, torque simulation, networking, tutorial and a production build remain
out of scope for this greybox publication.
The subsequent user-authorized experiments add parked controls, shared posture,
visual art, six-axis rate flight, throttle, traveling shots, sword hit feedback and scope.
