# Implementation dispatch

The user approved the plan and requested a separate Codex task in this new repo
to implement or orchestrate implementation subagents. Start work; do not ask
for another approval of the plan.

## Scope and endpoint

Implement `docs/mvp-plan.md` through **M0a and its automated preflight**, stopping
at the first actual user headset smoke test. Build a human-scale seated cockpit,
greybox exterior/range, XYZ translation/boost/brake, intentional yaw/pitch,
tracked-controller rifle and shield, predictable shot emitter, and one live
cockpit MFD with explicit arm/UI handoff. The first user gate checks scale,
bindings and the basic combined loop. Presets B/C follow that check per the plan;
do not turn this into the entire tutorial, full comparison campaign, or saber work.

The proposed thumbstick mapping is a draft, not a reason to halt before trying
it. Resolve ordinary implementation details; document any consequential change
to intended behavior and why it was needed. No auto-rotation from targeting or
hands, no global XR scale amplification, no hidden input ownership changes.

## Host and references

- Host sayu, new durable repo `/home/s/code/mech-vr`; no remote configured.
- User test target: seated PCVR, Beyond/Index tracked controllers, native OpenXR.
- Last verified installed engine: `4.7.2.stable.nixpkgs.ed1daf0bf`; verify locally.
- `/home/s/code/pet-demo` at `67779d4`: closest settings/desktop/input/UI/testing
  reference. Read its THIRD_PARTY.md for XR Tools pin `ccd795c0…` and its actual
  current GL Compatibility renderer. Adapt useful pieces; don't copy the large
  demo scene or blindly pull newer dependencies.
- `/home/s/lib/godot-xr-tools`: broader upstream reference; HEAD differs from
  pet-demo's vendored pin.
- `/mnt/s/code/mainspring`: body/target handoff reference; keep human cockpit
  scale and do not inherit its playspace leash.
- `/mnt/s/code/deckard/docs/godot-port-plan.md`: input source and ownership design.
- `/home/s/code/prim`: PCVR and small SubViewport UI reference.
- `/home/s/lib/VRC_Orbiter` at `86bb8ff`: later handle/rate/torque reference;
  existing prefabs choose angular rate, so physical stick design does not require
  Newtonian torque dynamics. Full rotation/handles are outside M0a.
- `/home/s/lib/OneEuroFilter` at `d789255`: optional observed-jitter remedy.
- `/home/s/org/projects/mech-vr/references.md`: verified paths, provenance and
  research. Authored natto-only notes are already copied under that directory's
  `references/own-designs/`; SSH natto is available if further inspection is needed.
- Planning task: `01a0a19d-ef1b-77b2-b7dd-0d46e20654d1`. Full initial research
  transcript: `/home/s/org/projects/mech-vr/references/chatgpt-design-transcript.md`.

## Execution and verification

Use subagents where independent bounded tasks help; keep integration ownership
clear and prevent conflicting file edits. Implement a runnable loop, not merely
scaffolding. Keep desktop/replay inputs capable of independently exercising head
and both hands. Test the meaningful failure modes listed in the approved plan:
movement/brake, coordinate transforms and reattachment, held inputs across UI or
tracking loss, actual-muzzle parallax, and finite swept shield interception.

Use pet-demo's isolated Monado runtime approach for nonphysical OpenXR smoke;
do not stop the user's normal runtime or launch a competing service on its socket.
Physical headset comfort, reach and controls require the user. Leave a short
test card, exact reproducible launch command, retained logs and honest evidence
boundaries at that gate. No renderer/platform/networking test matrix is needed.

Work around routine local issues when cheap and contained. Escalate annoyances
worth a durable user-side environment fix instead of piling on hacks. Include
what failed, the narrow fix, and whether independent work can continue. Do not
silently rebuild NixOS, alter global configuration or restart shared services.

Keep focused local commits with the configured human identity and actual model
Assisted-by trailer. No remote creation, publication or push. At the gate update
the org project note with branch/HEAD, dirty state, exact artifact/launch paths,
test results, implementation task id and the next human action; preserve the
vault's unrelated work. Then report that the build is ready for the user test.
