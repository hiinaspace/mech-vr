# M0a feedback — 2026-09-14

User reports the demo works quite well and arm toggling works fairly well.
Reattachment rebasing has a useful benefit: the shield can stay near the face
without keeping the physical hand raised. Tradeoff: accidentally rebasing an
awkward orientation, especially the rifle, is confusing/harder to recover from.
Preference between rebasing and a fixed global controller-to-arm reference is
unresolved. At that checkpoint a position-only rebase with calibrated orientation was a
possible future comparison; the next follow-up below implements it.

Requested follow-up implemented:

- Move the MFD down 30 cm (center y=-0.65 m), tilted upward 45 degrees.
- Add a small translucent 3D pose miniature beside the dashboard. It copies
  actual visible torso, canopy crossbar, arm segments, rifle and shield; held
  and reset-blended poses remain consistent. Body yaw/pitch is shown relative
  to the range in a fixed three-quarter presentation. Cyan body/shield and
  amber rifle distinguish sides. It does not alter input or arm targets.

Existing 549 checks and six-check rendered replay pass. Dashboard screenshot
inspected in `artifacts/dashboard-detail.png`; logs in
`artifacts/dashboard-tests.log` and `artifacts/dashboard-replay.log`.
New dashboard placement and miniature readability still need the user's headset
judgment. This feedback is not a recorded full timing/binding test or an A/B/C
comparison, and does not authorize expansion into those presets.

## Grip and flight follow-up

User reported the dashboard/mirror worked well enough and recorded a short demo.
They requested UNDERDOGS research, parked diegetic controls with grip release,
a live regrab comparison, and an articulated superhero/jetpack flight puppet.

Implemented hold-to-grab near the parked handle, distinct tracked-hand markers,
FREE versus CALIBRATED ANGLE (both rebase position), and live fallback to the
previous B-button mode. Interpreted the described release-grip gesture as hold
grip, rather than a sticky squeeze toggle. Detached stick inputs are masked;
brake remains available. Reacquisition, tracking recovery and mode changes
require fresh grip/trigger input rather than inheriting a held action.

Flight preview is an animation hypothesis: spine follows acceleration with a
bounded lean, velocity guides coasting, backpack jets represent the available
spine component, and a vernier represents the residual. It does not physically
rotate the cockpit or solve torque. The anatomical arm preview shows reach
limits separately from unchanged actual equipment targets. A live actual-rig
view remains available. The new interaction and posture need headset judgment.

Research and uncertainty are in [UNDERDOGS notes](research/underdogs-controls.md).

## Flight HUD and shared-body feedback

User finds parked handles workable and the articulated/thrust hologram improved,
but its body does not conform to the actual exterior rig. Next pose work should
use one shared anatomical solution for exterior and miniature: acceleration
response with hysteresis/deadbands, chest/head alignment constrained by actual
arm reach, and a separately stabilized cockpit holographic view. This pass
records that problem without introducing automatic cockpit motion.

Added sparse 3D HUD geometry: cockpit-forward datum, colony-relative horizon and
signed 10-degree pitch ladder, heading/pitch/speed, amber training-hostile contact
diamonds with live range, and an actual-impact GUN reticle. Contact and gun
symbols retain world depth, face the viewer, and maintain roughly constant
angular size. Overlay materials intentionally show through geometry, with no
occlusion inference, offscreen arrows, target lock, lead prediction or aim assist.
The range has only training targets; TRN-H is their identification, not a new
team/combat simulation. Heading zero is colony -Z, not magnetic north.

## Shared thrust posture pass

User reports the HUD works as intended and authorizes the thrust/body pass.
The exterior and hologram now share the same rig; the miniature copies geometry,
transforms and visibility rather than independently estimating a pose. It frames
the full current rig above its base. Gun and shield remain the actual control
model endpoints; shoulders/chest accommodate them. Six-metre upper/lower arm
segments use a visible sliding clavicle at workspace extremes, rather than
stretching bones or moving a parked weapon. This is a mechanical heuristic,
not a complete anatomical constraint/collision solver.

Posture remembers direction: thrust enters above 2 m/s² and exits below 0.7;
a new direction must differ by 10° and persist 0.22 s. Lean is bounded to 75°,
with a 65°/s maximum and eased settling. Braking against current velocity uses
retro thrust while retaining travel posture. Idle waits 0.45 s before settling;
coast retains a travel pose without exhaust. Low-speed motion uses separate
1.2/0.5 m/s entry/exit thresholds. These values are authored starting points.

Chest yaw blends useful hand directions with a smaller head contribution,
ignores hands behind the neck, and downweights close hands. It is limited to
about ±26° with a 6° deadband and 25°/s response. Pelvis/legs follow more slowly.
The exterior head follows a bounded, smoothed look direction around a fixed neck
anchor; the actual cockpit camera remains a stabilized holographic projection
in the explicit pilot-controlled frame. The user's head tracking is not filtered.

The incoming-shot chest hurtbox follows the visible chest. Gun/shield collision
and aim remain at the actual displayed equipment. The movement collision hull
is still the simplified cockpit-relative navigation hull; there is no per-limb
wall collision, self-collision, torque simulation or physical thruster allocation.
BODY POSTURE: THRUST / UPRIGHT now compares the shared body behavior, replacing
the previous independent miniature preview/actual toggle. Reset clears pose memory.

[Lone Echo / Space Junkies references](research/space-body-posture.md) support
prioritizing endpoints, inferred chest facing and delayed lower-body response;
they do not supply our thrust thresholds or cockpit model. The next user check
is sustained boost/brake/strafe while holding the shield and rifle independently.
