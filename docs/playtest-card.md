# M0 headset playtest card

Status: **not run**. First do the short M0a scale/binding check; use this card
after A/B/C work. About 12–15 minutes plus breaks, with permission to stop
immediately when a control or discomfort problem makes comparison unhelpful.
This is a personal design decision, not a statistical usability study.

## Record before starting

- Build commit and dirty state:
- Host / Godot / renderer / OpenXR runtime:
- HMD / controllers / active refresh rate / render resolution:
- Seat, armrests, neutral controller placement, handedness:
- Preset configuration file/hash and scenario/reset ID:
- Input trace / game log / optional mirror video paths:

Use one fixed scenario and fixed numerical tuning across presets. Do not adjust
speed, target sizes and servo response at the same time as the control style.

## Each run

1. **Navigate and stop (30–45 s):** move laterally, forward and vertically;
   pitch/yaw intentionally; look aside without changing course; boost toward a
   marker and brake beside it. Note right-stick mode mistakes and stopping error.
2. **Aim independently (30–45 s):** fire ten shots at the same silhouette while
   strafing. Look toward a side marker while maintaining the intended gun
   direction. B is expected to expose the cost of head-coupled aim here.
3. **Shield while firing (30–45 s):** block five slow telegraphed shots while
   aiming at the adjacent target. Move the shield aside once to verify that
   blocks depend on actual placement.
4. **Use the cockpit (30–45 s):** change emitter cadence on the live MFD while
   shielding; return to firing. Repeat handoff three times. Record unexpected
   fire, lost shield coverage, unexpected thrust, arm snaps and unclear modes.

Run A, then B/C in either order, then repeat the preferred preset briefly.
Write down the order; familiarity can bias the first comparison. Change one
tuning parameter only in a separately labeled retest.

## Results

| Observation | A: arms/hand UI | B: head aim/hand UI | C: arms/head UI |
| --- | --- | --- | --- |
| Run order / exact config | | | |
| Stop error and movement-mode mistakes | | | |
| Hits / 10 and aim held while looking aside | | | |
| Blocks / 5; placement feels predictable? | | | |
| Three UI handoffs: time / errors | | | |
| Unintended shot, thrust or arm snap (must fix) | | | |
| Arm/neck fatigue; acceptable resting pose? | | | |
| Motion discomfort before / after | | | |
| Sense of operating robot arms | | | |
| Frame-time / missed-frame evidence | | | |
| Would I choose to use this again? Why? | | | |

Log intended and actual arm transforms, input ownership transitions, fire/UI
edges, velocity, boost/brake state and shot/block events. A short ring buffer
dump on a manual “mark issue” action is enough; no analytics platform needed.

## Decision

- Preferred preset and reason:
- Combined move/shoot/shield/UI task works: yes / partly / no
- Remaining correctness issues (resolve before interpreting feel):
- One tuning or binding issue to retest, if any:
- Verdict: go / conditional-go / stop-pivot
- One next experiment: cockpit handles / flight dynamics / saber contact / none

A clear preference and a convincing combined action loop are the evidence.
Hit rate alone cannot settle fatigue, embodiment, awareness or UI handoff.
Do not treat greybox success as melee, multiplayer or cross-headset validation.

## Log

- 2026-09-14 [Codex] Created the unrun M0 comparison card, with fixed scenarios, control/comfort observations, correctness gates and an explicit next-experiment decision.
