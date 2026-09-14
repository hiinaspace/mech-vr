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
