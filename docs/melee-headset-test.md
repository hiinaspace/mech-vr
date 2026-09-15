# Melee contact lab: first headset test

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

## Five short comparisons

1. **Fixed guard:** move the right blade into the horizontal enemy blade. Try
   holding, sliding sideways, withdrawing and approaching again. Does the actual
   blade visibly stop while the amber requested-grip marker moves beyond it?
   Can you understand resistance from the load display, sound and vibration?
2. **Free opponent:** select BASE: FREE (resets paused), resume, repeat. Compare
   NORMAL, SOFT and COAST bracing. Each resets paused. Do body motion and recovery
   make sense? Coast disables body thrusters; arm motors still act on the torso.
3. **Slab / repeated cut:** cycle scenario. The slab isolates contact and hides
   the opponent; the repeated cut uses a periodic motor target. Practice shield
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
allocator. This gate evaluates contact, controls and feedback. Thermal damage,
ablating shields, dismemberment, voice/networking and competent combat AI follow
only after feedback. No subjective headset validation has been claimed.
