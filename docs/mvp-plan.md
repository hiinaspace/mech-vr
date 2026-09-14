# Mech VR: initial MVP

Planning date: 2026-09-14. Scope: an implementation-ready plan; no game code
has been written. User decisions: seated PCVR on sayu, Beyond/Index tracked
controllers, Godot, greybox assets, XYZ translation with boost/brake and
explicit yaw/pitch. Roll and direct-torque flight are later options.

## The first question

**Can I comfortably move one way, look another way, fire the rifle, and place
the shield independently—and still operate one cockpit control?**

Build a small repeatable range that answers this. The robot/cockpit relationship
is the distinctive part: human hands command large external actuators. A
positive result earns the next combat experiment; it does not establish that
melee, multiplayer or a campaign will work.

M0 contains a human-scale seat/cockpit frame, two simple external arms, a rifle,
a shield, a colony-wall/docking-truss backdrop, three targets and a predictable
incoming-shot emitter. HUD information is limited to actual aim, range, speed,
velocity direction, boost reserve and control ownership. One small MFD changes
the shot emitter's cadence. A separate paused test menu changes presets/tuning.

The emitter is necessary: carrying a shield without incoming fire would not
test the shield hypothesis. It needs no navigation, tactical AI or enemy rig.
Targets light up/count hits and reset; incoming hits count without ending a run.

Deferred: swords, intercept assist, lock-on steering, missiles, walking, legs/FBT,
destruction, meaningful damage resources, missions/tutorial scripting, art,
colony interiors/orbits, multiplayer, Prim integration and distribution tooling.

## Three presets in the initial demo

Use the same scene, movement motor, target distances, weapon and arm limits.
Presets are saved configurations, not separate scenes or control code forks.

| Preset | Rifle | Shield | In-cockpit UI | Question |
| --- | --- | --- | --- | --- |
| A — tracked arms / hand UI, proposed default | Right controller commands robot hand position and gun orientation | Left controller commands shield position/orientation | Explicitly detach one hand; its robot arm holds while that hand points/clicks | Does the full arm fantasy justify the reach and handoff cost? |
| B — head aim / hand UI | Head direction requests gun aim; same constrained external arm and actual muzzle | Same tracked shield as A | Same handoff as A; gun holds while the right hand owns UI | Is head aiming easier or less tiring, and what does it cost in free looking? |
| C — tracked arms / head UI | Same as A | Same as A | Head pointer selects within the MFD; a dedicated button clicks; both arms stay active | Can a small cockpit UI work without giving up either arm? |

B deliberately changes only rifle aim. This makes it possible to attribute a
preference. It is inspired by head-aim cockpit games, not a replica of Vox or
Silver Phantom. Full virtual levers change several things at once and are the
bounded follow-up D below.

Use **head pointer** in labels for HMD orientation. True eye-gaze is a different
input source and requires confirmed runtime/device support; do not quietly call
head aiming eye tracking. Godot exposes an eye-gaze support query, but this plan
does not claim that the user's current headset/runtime supplies gaze poses.
[Godot OpenXRInterface](https://docs.godotengine.org/en/stable/classes/class_openxrinterface.html)

## Movement and bindings

Start with cockpit-relative **velocity command**: stick input requests an XYZ
velocity, with acceleration limits. Release requests zero velocity and the
verniers slow the suit. Boost temporarily raises acceleration/speed and drains
a small rechargeable gauge. Brake strongly reduces velocity in every direction
and works even when boost is empty. Brake wins over boost and movement while held.

Keep world velocity as state. Rotating the cockpit does not rotate existing
momentum; it changes the direction of future commanded thrust. Looking around
never changes the movement frame. This is a deliberate adaptation of GBO2's
camera-relative spatial movement: an independently tracked VR head should not
steer the pilot's intended path whenever they inspect a panel.
[GBO2 space-control revision](https://bo2.ggame.jp/en/info/?p=14784)

Yaw/pitch request angular rates, with short acceleration/deceleration ramps;
release arrests rotation. The cockpit rotates only from explicit pilot input.
No auto-facing, camera shake, recoil kick, arm-driven torso following, banking
or automatic leveling. Provide optional snap yaw and adjustable smooth yaw/pitch.
Roll is locked in M0; limit pitch before the vertical singularity (initially
±75 degrees relative to the range frame). This is five controllable motion axes,
not a claim of unrestricted six-axis flight.

Two thumbsticks provide only four analog axes. The first concrete mapping uses
a visible pitch/vertical switch; that compromise is itself part of the test.

| Input, right-handed preset | M0 behavior |
| --- | --- |
| Left thumbstick XY | Strafe left/right and forward/back |
| Right thumbstick X | Yaw |
| Right thumbstick Y | Ascend/descend in normal mode; pitch in attitude mode |
| Right lower face button A | Toggle vertical/pitch mode; show the current function beside the stick and on the HUD |
| Left trigger | Hold boost |
| Left lower face button X | Hold brake; available during every UI state |
| Right trigger | Fire, or click only while right hand explicitly owns hand UI |
| Either upper face button B/Y in A/B | Toggle that hand between arm control and cockpit UI; only one UI owner at a time |
| Right B in C | Enable/disable head-pointer UI focus |
| Left Y in C | Dedicated UI click while focused; never a weapon action |
| Grip | Unassigned initially; test hold-to-clutch later if useful |

Changing the right-stick mode requires returning that stick to neutral before
its Y axis becomes active again. The label must explain the mapping; it cannot
silently turn an ascent command into a pitch command. Simultaneous vertical
translation and pitch is not available in this draft binding. If that gets in
the way during the first navigation exercise, test a single alternate mapping
or virtual handles before interpreting the result as a failure of the flight
model. No requirement to build a general remapping editor for M0.

Keep boost/brake in the left hand so the pilot can aim/shoot while stopping.
If that hand is in UI, its trigger belongs to UI and boost is inhibited; brake
keeps its dedicated button. Other movement axes keep their meaning while the
live MFD is open. The test/settings menu pauses simulation and neutralizes
control input; it is a separate path from the live MFD.

## Robot arms, scale and aim

Keep the cockpit and tracking space at **1 metre per metre**. Put the player
inside an approximately 18 m robot represented by a torso box and two segmented
arms. Scale external arm command displacement, not the headset/IPD or whole
XROrigin. A seat edge, human-sized handles, an exterior maintenance doorway and
an 18 m target silhouette establish the two size scales.

On calibration, record a comfortable seated neutral pose for each controller.
In cockpit coordinates, hand displacement from that neutral drives a robot-hand
target around its own neutral pose. Start near 8× position gain with independent
XYZ gains exposed; orientation gain starts at 1×. Clamp reach and joint angles;
a stable two-segment visual arm is enough. Show a small intended target marker
only in debug view, and the actual weapon/shield pose in play.

The cockpit hands/handles follow tracking promptly. External arms follow desired
poses with bounded speed/acceleration. Start with a responsive setting and one
heavier setting; do not bake in the transcript's speculative several-hundred-ms
lag. Distinguish controller jitter filtering from actuator response. Heavy
filtering of all tracking would undermine the control test. The 1€ filter is a
small optional tool if idle hand/gun jitter is actually visible; its parameters
trade jitter against lag. Reset filtering on reattachment.
[Author's filter reference](https://gery.casiez.net/1euro/)

Cockpit, robot torso and shoulder anchors share one explicit body frame in M0.
Head movement changes only the pilot camera. External torso tracking and AMBAC
animation remain later work. In particular, letting an arm reach a limit must
not turn the cockpit to help it.

Rifle shots originate at the **actual muzzle**, after servo limits. Start with
a hitscan beam and a short visual flash; no projectile lead calculation, auto
aim, reload gesture or weapon swap. A reticle shows the muzzle's collision point
or range-limit point, so its parallax agrees with the shot. Head aim in B sends
the head ray's world point to the same aiming solver; it never shoots directly
from the camera. Check muzzle clearance near the colony wall and shield.

The shield is a finite slab on the left arm, initially around 4 × 6 m. It blocks
only shots that intersect it before the simplified torso hurtbox. It must work
at an angle and fail when held beside the threat. Player beams should also hit
the shield if it crosses their path. Don't hide this coordination cost with a
shield-up flag or 360-degree defense.

Use a slow, brightly telegraphed incoming bolt to make placement observable.
Sweep its segment between physics positions; a fast bolt must not tunnel
through the shield. Consistent pose timing for shield visuals and collision is
part of correctness. Log commanded versus actual poses to explain apparent
misses; don't let a render-only shield position disagree with the collision.

## Detaching a hand is an explicit state transition

The default follows the user's petting UX preference for explicit/sticky modes
on Index, rather than accidental grip release. Each hand has one owner:
`ARM`, `UI`, or `HOLD` (tracking loss); later `PILOT_HANDLE` can be added.
The physical tracked pose remains available in every state. “Detached” means
the arm stops consuming that pose, not that tracking stops.

For A/B:

1. B/Y requests UI for that hand. Hold its **actual** external arm pose in
   cockpit space, zero that arm's servo velocity, cancel that hand's combat
   action, and suppress already-held triggers until released. The other arm
   keeps working.
2. Display `RIGHT ARM HOLD / RIGHT HAND UI` or its left equivalent. Move the
   human hand freely to operate the panel using a controller ray and trigger.
   Merely hovering a panel never changes ownership. Touch/poke can be a later
   pointer backend if the ray test identifies a need.
3. B/Y returns to arm control. Rebase the hand-to-arm mapping at the current
   hand pose and held arm pose so there is no snap. Subsequent hand displacement
   and orientation deltas move the target from that pose. Require trigger
   release followed by a fresh press before firing/boosting again.
4. Repeated clutching can shift the usable arm workspace. A separate paused
   recalibration/reset returns it to the calibrated neutral, with an explicit
   pose blend while weapons are inhibited. Never silently recenter mid-fight.

For position, a reattachment can be described as
`robot_target = held_robot_pose.position + gain * (hand_now - hand_at_attach)`
in cockpit coordinates, followed by reach limits. For orientation, use a
consistent quaternion delta in that same frame, not subtraction of Euler angles.

In B, resuming the rifle instead reacquires the current head-ray target through
the bounded servo; it does not rebase a hand-controlled gun. Keep fire inhibited
until the trigger has been released and reacquisition has completed, then require
a fresh press. Show the actual muzzle reticle throughout that transition.

For C, explicit UI focus enables the head ray only for cockpit panels. Looking
at the MFD highlights; clicking needs the separate Y press. No gaze dwell to
activate controls and no trigger reuse. Both arms remain live, so the same shield
exercise continues during UI use. The MFD can capture the pointer until focus
exits, preventing selection from jumping to a world target. This is suitable
for a few large controls; it does not prove that dense MFDs or typing will work.

On lost hand tracking, hold that arm and stop its fire/boost output. Resume
with pose rebasing and a fresh action edge. If the HMD/session loses focus,
pause the single-player simulation, clear held inputs and keep tracking-driven
view updates alive where available. One MFD must receive one click sequence;
switching focus must send releases to the old owner. The paused menu must not
be the only tested UI path, because it conceals the in-flight handoff cost.

## Range layout and initial tuning

Use a local range a few hundred metres across beside a nonrotating cylinder
section or broad curved wall. Add a docking truss and nearby markers for
motion/scale. A full O'Neill cylinder mesh can be a cheap background silhouette;
its kilometers of playable surface and orbital dynamics are unnecessary.

Three exercises share this scene: fly to a marker and stop; shoot while strafing
past another marker; keep the shield between the emitter and torso while aiming
elsewhere. The MFD cadence change is a fourth action inside the shield exercise.
Spawn/reset returns to exactly the same arrangement.

These are **editable starting values, not findings or acceptance standards**:

| Parameter | Starting point |
| --- | --- |
| Cruise / boost speed | 12 / 30 m/s |
| Cruise acceleration / release deceleration | 12 / 8 m/s² |
| Boost acceleration / brake deceleration | 30 / 45 m/s² |
| Boost reserve / full recharge | 2 seconds of boost / 4 seconds at rest from boost |
| Yaw / pitch maximum rate | 30 / 20 degrees/s; short rate ramp; lower values available |
| Arm response comparison | Responsive versus bounded heavier servo, recorded as exact parameters |
| Targets | 10–18 m silhouettes at roughly 60, 120 and 200 m |
| Incoming bolt | About 40 m/s from 60 m; 0.5 s telegraph; one every 2–3 s |

At 30 m/s and 45 m/s² braking, the ideal stop is about 0.67 s and 10 m before
input/actuator delay. Put the first stop marker well clear of the wall, and
show a debug stop-distance estimate when tuning. Normalize translation input
to avoid faster diagonal flight; brake must not reverse velocity or depend on
render frame rate. World collision stops/slides the simplified body without
knockback or automatic rotation.

Cockpit instruments sit on the console or canopy structure with readable
depth, not a panel rigidly stuck to the player's eyes. Use a stable cockpit
frame and nearby exterior references. Vox's developers explicitly describe
stabilizing the seat relative to machine motion; that supports testing a stable
cockpit first, not borrowing third-person camera jolts.
[Vox cockpit-chair design](https://www.voxmachinae.com/articles/2015-01-19_cockpit_chair.shtml)

## Implementation shape and reuse

Create a new standalone `/home/s/code/mech-vr` project when implementation
begins. Use GDScript, installed Godot 4.7.2, native OpenXR, and primitive meshes.
Start from pet-demo's explicit settings/input/test patterns and its pinned
XR Tools `ccd795c0…` dependency, not its large demo scene. Its actual current
renderer is GL Compatibility; use that as the initial greybox baseline and
record the renderer in test results. Reconsider only for a concrete limitation.
Use stock physics queries/kinematic body movement; no engine fork/GDExtension.

```text
OpenXR or desktop/replay input
    -> input sample: poses, validity, buttons, sticks, timestamps
    -> ownership + selected control mapping
        -> desired velocity / angular rate -> suit motor
        -> arm targets -> limits / servos -> actual muzzle + shield
        -> panel pointer / click
    -> shot resolution, HUD, haptics, run log
```

Keep four concrete responsibilities separate: input/ownership, suit motor,
arms/weapons, and range/UI. One saved settings object supplies presets. Input
sampling and collision resolution have an explicit update order; avoid each
component independently reading raw button state. The XR camera/controllers
retain native tracking updates even while gameplay is paused. A floating
kinematic body owns suit movement; don't inherit pet-demo's floor locomotion,
teleport or a second PlayerBody origin mover.

An input snapshot is enough abstraction for desktop/replay and controller
variants. No general interaction framework, plugin architecture, or networking
protocol is needed. Desktop testing must independently manipulate both hand
poses and head direction, or replay recorded poses; a mouse that simultaneously
aims everything cannot test the core hypothesis.

| Existing project | Use here |
| --- | --- |
| pet-demo | Live settings, interaction ownership, controller/desktop adapters, haptic cues, isolated Monado runner and headset-test separation |
| Mainspring | Explicit targets and controlled body/arm handoff; keep its global avatar scale changes and playspace leash out of this cockpit |
| Deckard plan / grab-resistance note | Input-source separation, deliberate gesture states, haptic confirmation, cancel/release semantics |
| Prim | Small 3D viewport UI and real PCVR setup references; media/voice/launcher remain separate |
| humanoid-pose / Quakespasm avatar work | Tracking-loss and actual-versus-commanded-pose lessons; full-body estimation/VRM are unnecessary for two greybox arms |
| RGBD spectator / OpenXR overlay | Future spectator ideas; this game renders its own scene and needs neither capture reconstruction nor an overlay session |

Current paths, revisions and evidence limits are in [reference investigation](/home/s/org/projects/mech-vr/references.md).

## Build order and evidence gates

| Step | Deliverable | Gate / stop condition |
| --- | --- | --- |
| M0a | One seated cockpit, range references, movement/boost/brake, A arms, rifle, shield emitter and live MFD | Focused deterministic checks and desktop/replay pass; then short actual headset check for scale, tracking and binding correctness. Fix this before more modes. |
| M0b | B head-aim switch and C head-pointer UI using the same scene | Ownership transition checks pass; no stale fire/clicks, no arm snaps, no hidden cockpit steering. |
| M0 playtest | Three brief matched runs and a repeat of the preferred preset | Fill [playtest-card.md](playtest-card.md); choose go/conditional-go/stop and one next pull. End the first spike here. |

Focused tests should cover behavior that can invalidate the experiment:
translation normalization, acceleration/brake/no-reversal; head/arm motion
cannot rotate the cockpit; clutch in a translated/rotated cockpit; repeated
reattach without a snap; held-trigger input across UI/focus/tracking changes;
muzzle parallax; shield-before-torso versus shield-beside-torso and swept hits.
Check motion at several simulation step sizes against expected tolerances,
not just against a second copy of the implementation formula.

Then do one isolated OpenXR startup/binding smoke using pet-demo's private
Monado runtime approach. This can prove action/pose plumbing, not visual comfort
or hand reach. Do not disturb the normal headset runtime to run that simulation.

Actual headset gate: confirm both controller bindings and tracking, usable
seated reach, stable cockpit scale, clear muzzle/reticle agreement, readable
instruments, and frame timing at the headset's active refresh rate. A flat
screenshot or successful startup cannot establish those. Record CPU/GPU frame
times and missed/reprojected frames where available; do not claim physical
motion-to-photon latency from input timestamps alone.

Go means the user can complete the combined movement/shoot/shield/UI task,
understands any held-arm state, and prefers at least one configuration enough
to explore another combat verb. Conditional-go means one named problem gets
one bounded retest. Stop/pivot means stationary arms or flight still feel poor
after that retest; retain the harness rather than growing a tutorial around it.

## Conditional follow-ups, not M0 requirements

**D: cockpit-handle preset.** In the same sandbox, left hand displacement from
a grabbed neutral commands XYZ velocity; right hand tilt/twist commands yaw/pitch,
then optional roll. Rifle uses head aim; shield begins as an explicitly commanded
front guard so handles can own the hands. This is a whole cockpit interaction
alternative, not an isolated rifle-aim comparison. If independent shield
placement is required here, test a temporary left-hand shield-control state
instead of mapping the same pose to steering and shielding implicitly.

VRC_Orbiter supplies a concrete reference: `VPControls.cs` separates local-frame
translation, joystick orientation, grab resets/filtering, and output commands.
Its inspected prefabs select angular-rate control; the code also offers direct
torque. First try its style of hand input with our existing assisted motor.
Only then compare drift or torque, so a preference can be attributed. Full
physical simulation is not needed to support a three-axis joystick.
[VRC_Orbiter](https://github.com/Astro-Rabbit/VRC_Orbiter)

**Flight dynamics.** Compare release-to-slow versus coasting, or rate versus
torque, one at a time with the winning input mapping. Preserve an explicit brake
and pilot-owned cockpit rotation. Add unrestricted roll only in that separate
run. Record these as gameplay choices, not increasing levels of realism that
the project is obligated to reach.

**First saber gate.** After ranged/shield control passes, one blade and a static
blocker: does an external servo arm stopping/deflecting while the human controller
continues feel understandable? Then a single dummy intercept with optional
translation assistance. No target-driven cockpit rotation. This is where the
original force-feedback/large-robot hypothesis becomes a contact test.

## Log

- 2026-09-14 [Codex] Planned M0 around the confirmed seated PCVR target, three control presets, explicit arm/UI ownership, local-frame motion and a bounded headset decision; retained cockpit handles and full rotational dynamics as conditional follow-ups.
