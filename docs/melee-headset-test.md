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
