# Melee contact lab: tuning and movement test

## Run

From a graphical terminal after your normal VR startup:

```sh
/home/s/code/mech-vr/scripts/run-melee.sh --xr
```

Desktop: `./scripts/run-melee.sh`. If the task environment lacks display variables,
prefix rendered commands with `DISPLAY=:0 WAYLAND_DISPLAY=wayland-1`.
The original ranged prototype still launches with `./scripts/run.sh`.

Starts paused. Reset/calibrate seated with R or the cockpit panel, then resume
with right stick click / Escape. Hold grip near each parked cockpit handle to
acquire it; release to use the panel with pointer/trigger. Existing arm-stick
flight controls apply while holding handles. Left A / desktop Space brakes.
Desktop mouse aiming requires right mouse; keyboard shortcuts appear on the panel.

## Heat trails, stable arms and calibration

**Trails:** drag the beam across the shield, then across an arm or leg. Heat now
adds across overlapping brush footprints, remains where painted, and fades with
about a 1.7-second half-life. The eight-spot eviction limit is gone. All visible
solid armor/limb/hilt meshes participate; beam glow and exhaust do not. These are
visual heat surfaces, not new physical limb bodies or damage/destruction.

**Arm drift:** parked targets now remain fixed in the robot's local reference
frame. They no longer chase the previous physical hand position when acceleration
causes actuator lag. Both live and parked arm commands use the fixed robot-head
reference and 8× position mapping. HMD translation does not enter that mapping;
body translation/rotation does not accumulate into a parked target.

Real controller **thumbstick** translation follows current head rotation; its
pitch command uses the current head-right axis. Yaw remains robot-local upright.
This applies continuously, per the requested comparison. The physical six-axis
virtual stick and persistent throttle remain cockpit/robot-relative, independent
of head pose. Looking without moving a stick does not command motion.

### Move the handles away from the maneuver stick

Use zero RTT and the stationary guard for an easy first calibration:

1. Open **ARM CALIBRATION** on the panel or press **F3**. Resume if paused.
   Flight/boost are inhibited while calibrating; finite arm motors still run.
2. Grip a parked arm handle and put that robot arm where you want it.
3. Release the trigger once, then **hold that hand's trigger**. The arm's
   requested pose stays fixed. Move and rotate the cockpit handle somewhere
   comfortable, clear of the center maneuver stick.
4. Release trigger: further handle motion controls the arm with the new offset.
   Repeat for either hand. Translation and rotation offsets are independent per arm.
5. Release the handle and choose **FINISH + SAVE OFFSETS** (or F3). Saved offsets
   reload next launch. **CANCEL** restores the prior mapping; **RESET OFFSETS**
   restores defaults, which are only persisted when you Finish.

Offsets are stored in Godot's per-user `user://melee-arm-calibration.cfg`.
R resets the scene/seated origin while retaining saved/current offsets; robot
arms return to neutral and cockpit handles move to their corresponding positions.
After calibration, release grips/triggers and regrab before maneuvering/boosting.

### Read the input and actuator difference

- The center stick has an amber origin tether, neutral/current RGB axes, a purple
  angular-demand vector and signed pitch/yaw/roll bars. These show its actual
  deadzoned input, not simulated vehicle momentum.
- Cyan wire grips show current robot hand poses mapped back into cockpit space;
  amber wire grips show requested poses. Their connecting lines and orientation
  axes expose actuator lag. Captions show cockpit-space centimetres and degrees
  (the positional error is compressed by the same 8× arm gain).
- Replay retains the cockpit error poses and painted trails. Imported older clips
  without cockpit error data simply omit those indicators.

Check a released shield during sustained throttle, then brake and reacquire it:
its requested position should stay put rather than ratcheting farther away.
Actual actuator error can still grow transiently if thrust exceeds arm strength.

## Beam-contact experiment

Beam swords now physically resist **only other beam swords**. Shield/body contact
stops the visible beam at the first surface reached from the hilt, but cannot
push, knock or stop the sword hand. The full-length overlap query continues while
the beam is visually shortened, so holding position keeps heating that surface.
Heat is still visual-only: no health, ablation or impact damage is implemented.

Try these comparisons:

1. Hold the blade against the opponent's shield/body, then make a fast pass.
   The sustained contact should become brighter; a quick pass deposits less heat.
2. Move the hand through the shield and withdraw. The beam should shorten and
   re-extend without pushing the shield. Only the first armor surface absorbs it;
   a visually hidden beam extension should not clash with another saber behind it.
3. Meet the other saber in open space. This still binds and transfers force.
   Use replay to compare armor overlap with an actual blade clash.
4. Select repeated cut: the raised position and downswing now stay on the dummy's
   **right/sword shoulder** side. Speed and motor limits still apply.

A cool, offset shoulder spotlight casts directional highlights/shadows across the
close fight. It follows the displayed suit, including during delayed-state and
replay viewing; no head-driven camera rotation or renderer change was introduced.

The collision model still covers torso/shield boxes, not every visible limb.
Own-suit armor is ignored, consistent with the existing self-collision exclusion.
The slab fixture also permits passage and shortens the beam; painted heat remains
on modeled robot torso/shield surfaces. Extremely fast sub-tick intersections may
be missed by the thermal sampling; this is not a continuous volumetric burn model.

## New tuning pass (2026-09-16)

Open **TUNE FORCE / SPEED / LAG** on the lower cockpit panel (desktop **F2**).
Point a free hand at a slider and hold trigger while dragging horizontally.
Settings change live, including while the other hand controls an arm. Grip release
parks the arm; the pilot stick/throttle owning a hand prevents panel clicks.
The panel is 20% smaller, lower and tilted up 45 degrees; look down to operate it.
The paired puppet is 28% smaller and outlined; arm color shows **actuator load as
fraction of the current force/torque limit**: green → amber → red.

| Slider | Range | What it changes |
| --- | --- | --- |
| Arm force | 1–180 kN | Translational motor strength, both suits |
| Arm torque | 1–180 kNm | Rotational motor strength, both suits |
| Arm response | 0.25–4× | How aggressively motors close pose error |
| Thrust | 0–900 kN | Base translational thruster budget |
| Attitude | 0–1,500 kNm | Body rotation compensation budget |
| Slash speed | 0.5–10 rad/s | Requested overhead downswing speed |
| Ping RTT | 0–400 ms, 10 ms steps | Half input delay, half committed-pose return delay |

Increase force/response separately to distinguish strength from tracking speed.
The repeated cut now raises the blade overhead, pauses briefly, cuts down and
recovers. Actual motion remains force-limited. Limits/slash settings affect both
suits as applicable. K/panel cycles NORMAL/SOFT/COAST bracing live; custom thrust
values are labelled CUSTOM. Reset resets the encounter, retaining tuning.

**Movement:** grip the cyan center stick with either free hand: displacement
requests XYZ velocity; tilt/twist requests pitch/yaw/roll. Release centers it.
The amber left-hand throttle requests persistent robot-forward thrust; brake
closes it. A nearby movable arm handle takes grab priority if handles overlap.
Hold the **left arm handle**, release then squeeze left trigger for boost;
boost raises requested maneuver speed and the player's finite thrust budget
(2.5×). Left A / Space brakes and wins over boost. Holding the pilot stick or
throttle in the left hand assigns its trigger to that control, not boost.
Desktop G/H hold left/right grips, Shift is left trigger, and Tab still switches
vertical/pitch mode. Keys 1/2/3 select head/left/right pose; RMB rotates the selected
pose, Ctrl+RMB translates XY, Alt+RMB moves depth. LMB is right trigger.

**Lag:** try 0, 100, 200 and 400 ms on the same contact. Local tracking, hands,
UI and control intent stay immediate. Physics runs authoritative arm/thruster
loops on delayed target commands; exterior, cockpit travel/attitude, puppet,
contact sound/haptics and visual heat use returned committed state, with no
prediction. Sampling adds up to roughly two physics ticks beyond nominal RTT.
Live physics tunables are operator settings, not delayed network commands.
Changing RTT clears old queues and holds the previous displayed pose until new
samples arrive; it does not rewind/reset the fight. Pause/replay also flush queues.
This models fixed symmetric latency only: no real transport, jitter, packet loss,
remote player or prediction/reconciliation is implemented.

Brushed metal now catches light; saber contact paints a fading hot spot onto body
or shield armor using DrawableTexture2D. It causes **no damage or heat gameplay**.
Replay retains heat marks, load colors, settings and RTT with the resolved poses.

## Five short comparisons

1. **Fixed guard:** move the right blade into the horizontal enemy blade. Try
   holding, sliding sideways, withdrawing and approaching again. Does the actual
   blade visibly stop while the amber requested-grip marker moves beyond it?
   Can you understand resistance from the load display, sound and vibration?
2. **Free opponent:** select BASE: FREE (resets paused), resume, repeat. Compare
   NORMAL, SOFT and COAST bracing. Each resets paused. Do body motion and recovery
   make sense? Coast disables body thrusters; arm motors still act on the torso.
3. **Slab / repeated cut:** cycle scenario. The slab isolates contact and hides
   the opponent; the repeated cut uses a periodic overhead motor target. Practice shield
   placement and blade interception. These objects cannot yet burn or break.
4. **Readability:** look at the blue/orange puppet pair while crossing weapons.
   Can you tell which arm is constrained and where the opponent is facing?
   Stabilized cockpit is default. Physical cockpit rotation is an optional
   comparison via C/panel; reset or switch back if unwanted.
5. **Replay:** T/panel freezes live simulation and keeps the last 20 seconds.
   Play/pause, scrub one second, switch cockpit/free-flight view and inspect.
   F8 marks the moment; F5 exports the clip plus notes under `artifacts/`.
   N opens desktop text annotation (Enter submits); in XR it adds a generic mark.
   Free view uses WASD/sticks, Q/E for height and arrows for yaw.
   Return to live stays paused and releases the handles for a fresh grab.

Reopen a saved clip on desktop:

```sh
./scripts/run-melee.sh --replay-file /absolute/path/to/artifacts/melee-TIMESTAMP.json
```

Useful feedback: “At 7.2s I expected to slide off, but it felt stuck,” whether the
puppet explained it, and which bracing setting made the exchange most deliberate.
Save separate clips before starting a new replay: notes belong to the active clip.
Replay records poses and contact telemetry, not microphone audio or video.

## Scope

Real torso/shield/blade rigid bodies use bounded arm force/torque and body thrust.
Limbs are visual IK; there is no full articulated joint chain or individual nozzle
allocator. This gate evaluates contact, controls and feedback. Physical thermal damage,
ablating shields, dismemberment, voice/networking and competent combat AI follow
only after feedback. No subjective headset validation has been claimed.
