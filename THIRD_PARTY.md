# Reference provenance

M0a uses Godot's native OpenXR nodes and physics. No XR Tools addon or vendor
binary is required by this bounded cockpit adapter. This is a deliberate narrow
adaptation of the plan: there is no floor locomotion, PlayerBody mover, teleport,
hand rig, or general pointer framework to justify importing the complete addon.

- `openxr_action_map.tres` derives from `/home/s/code/pet-demo`
  commit `67779d4d76297b603e680b418688026b3bff21de`. It retains only the Valve Index, Oculus Touch
  (isolated QWERTY simulator) and Khronos simple-controller profiles. The native
  Godot ResourceSaver retained their dependency closure and pruned other profile
  bindings. Retained `aim`, trigger, thumbstick and A/B bindings are unchanged.
  Simple controllers cannot exercise the full dual-stick/face-button loop.
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

## Starfield art pass

`assets/sky/space_*.png`: **Space skybox**, kurtk84, submitted by Calinou.
[Source listing, CC0](https://opengameart.org/content/space-skybox-1).
The archive additionally includes WTFPL v2 text, preserved as `assets/sky/space.txt`.
Source URL, retrieval date and archive SHA-256 are in `assets/sky/SOURCE.md`.
No image pixels were modified; the runtime shader adjusts brightness and adds
an authored sun. Cylinder, mirrors, nozzles, sword, trails and shaders are
repo-authored primitives/code; no Gundam franchise assets were imported.
