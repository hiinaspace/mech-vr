# Space body posture references

Research date: 2026-09-14. These are primary developer accounts, with proposed
adaptations separated below. They concern embodied human-scale avatars; our
seated pilot commanding a larger, independently articulated robot is different.

## Lone Echo / Echo Arena

Jacob Copenhaver, Ready At Dawn, **It's All in the Hands: VR Animation and
Locomotion Systems in Lone Echo**, GDC 2017:
[session](https://www.gdcvault.com/play/1024446/It-s-All-in-the),
[slides with speaker notes](https://media.gdcvault.com/gdc2017/Presentations/Copenhaver_Jacob_ItsAllIn.pdf).

The talk includes the single-player and team multiplayer project. PDF pages
33–41 describe heuristic upper-body estimation: chest facing blends head look
and directions toward both hands, reducing influence from nearby hands and
ignoring hands behind the body. The arm rig can change length to preserve
tracked hand positions. Spine and legs form a separate constrained chain:
motion propagates from neck downward, producing lag, with authored animation
additives. Pages 12–14 describe deliberately modified physics to avoid moving
the player's head merely because they wave a held object. This is concrete
evidence for prioritizing player control over literal physical simulation.

This is a 2017 implementation account, not proof of every later Echo VR
revision. It does not document our spine-thrust or parked-handle behavior.

## Space Junkies

**Part 1 — Space Junkies and Virtual Embodiment**, Ubisoft team with programmer
Samuele Panzeri, 2019-02-28:
[developer article](https://developers.meta.com/horizon/blog/space-junkies-and-virtual-embodiment/).

Their reconstruction estimates body facing from head/hands and previous state,
then hips, then constrained intermediate joints. Animator-designed pose inputs
help refine comfortable arm configurations. Matching the tracked head and hands
takes priority over an otherwise realistic-looking pose. The article describes
the stages but does not publish numerical filters, hysteresis thresholds or
the complete solver.

**Part 3 — Zero G Locomotion and Level Design for Space Junkies**, Ubisoft team,
2019-03-26:
[developer article](https://developers.meta.com/horizon/blog/space-junkies-locomotion-level-design/).

They tried highly inertial simulation and moved toward more controllable
movement. Drone maneuverability, flyboards and simulated skydiving informed
their design. HMD-directed travel, 45-degree snap rotation, helmet/body anchors,
blinders and clear environmental up/down cues are documented choices. Their
comfort observations are from their own testing, not a guarantee for this game.
This article does not describe an automatic body bank or a stabilized camera
inside an independently rotating robot head.

## Proposed heuristics for this prototype

These are our design choices, not claims about either game's algorithms:

- Use one resolved robot pose for exterior and hologram, with actual shield and
  muzzle transforms as authoritative endpoints. Let torso/shoulders accommodate
  the arm workspace before forcing the equipment away from the pilot's intent.
- Separate sustained propulsion posture from brief course corrections. Give
  thrust entry/exit different thresholds, retain posture briefly on coast, and
  settle more slowly than thrust begins. This prevents small acceleration
  changes from constantly flipping the suit between poses.
- Blend chest facing toward useful arm/head directions with limited influence;
  downweight a shield held close to the face and ambiguous crossed/behind arms.
  Let pelvis and legs follow more slowly so the body reads as a substantial
  machine rather than a rigid arrow.
- Treat backpack thrust as the visually dominant component along the spine;
  use verniers for braking and residual acceleration. Do not flip the entire
  body for a short reverse impulse or imply flames during true zero-thrust coast.
- Keep the cockpit's holographic view stabilized in its pilot-controlled frame.
  Exterior head articulation can communicate looking/aiming without feeding
  procedural torso motion into the XR camera. Any later camera coupling should
  be an explicit, separate headset comparison.

The key adaptation is a hierarchy of constraints and remembered intent, rather
than asking instantaneous acceleration to determine the whole robot pose.
