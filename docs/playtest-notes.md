# M0a feedback — 2026-09-14

User reports the demo works quite well and arm toggling works fairly well.
Reattachment rebasing has a useful benefit: the shield can stay near the face
without keeping the physical hand raised. Tradeoff: accidentally rebasing an
awkward orientation, especially the rifle, is confusing/harder to recover from.
Preference between rebasing and a fixed global controller-to-arm reference is
unresolved. Current behavior remains; a position-only rebase with calibrated
orientation is one possible future comparison, not implemented or selected.

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
