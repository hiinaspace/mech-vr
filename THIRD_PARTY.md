# Reference provenance

M0a uses Godot's native OpenXR nodes and physics. No XR Tools addon or vendor
binary is required by this bounded cockpit adapter. This is a deliberate narrow
adaptation of the plan: there is no floor locomotion, PlayerBody mover, teleport,
hand rig, or general pointer framework to justify importing the complete addon.

- `openxr_action_map.tres` is copied unmodified from `/home/s/code/pet-demo`
  commit `67779d4d76297b603e680b418688026b3bff21de`. It includes the Valve Index
  profile and preserves native `aim`, trigger, thumbstick and A/B bindings.
- The input/settings and isolated Monado runner patterns were inspected in that
  same permitted Godot reference; `scripts/run-monado-qwerty.sh` adapts its private
  runtime-directory runner and explicitly requests this application's XR mode.
- That reference's Godot XR Tools pin is
  `ccd795c0d57944f15f4c39d44d284347c74b11fc` (4.6.0-dev1, MIT), as recorded by
  its `THIRD_PARTY.md`. The addon itself is not copied or required here.
- Installed engine verified during implementation: Godot
  `4.7.2.stable.nixpkgs.ed1daf0bf`.
- Installed Monado runtime manifest:
  `/run/current-system/sw/share/openxr/1/openxr_monado.json`; its library store
  identifies Monado revision `5b133708c18aa16d17a976402daa7b4349aff912`.

Original Industrial Petting Unity source was not accessed or used.
