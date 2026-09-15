# Working guidance

Read `docs/IMPLEMENTATION_BRIEF.md` and `docs/mvp-plan.md` before implementation.
The user approved autonomous implementation through the first user testing gate.
Use implementation subagents for useful bounded independent work if helpful;
the main task owns integration and verification. Do not create extra sidebar tasks.

The first gate is M0a's actual seated headset smoke, after automated/desktop and
isolated OpenXR preflight. Stop with a runnable build, exact command and short
user test instructions when ready. Do not claim subjective headset validation
from simulation or expand into subsequent gameplay gates automatically.

Make routine reversible repo/environment setup decisions autonomously. Flag
environment annoyances where a durable user-side fix is preferable to accumulating
workarounds, with the exact failure and proposed fix. Do not change system NixOS
configuration, restart shared Codex/VR services, or disrupt other work silently.

Preserve unrelated dirty files in all reference repositories and the org vault.
Original Industrial Petting Unity source is outside scope; use the permitted
Godot pet-demo and authored UX notes only. The user authorized the initial private GitHub push. Further pushes require
user authorization; no public visibility change is authorized.
Use Hiina <hiina@hiina.space> for repository commits and add
`Assisted-by: Codex:<actual-model-id>`; never Signed-off-by. Keep useful local
milestones committed without including generated caches, recordings or secrets.
