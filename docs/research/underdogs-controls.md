# UNDERDOGS: useful control references

Research date: 2026-09-14. This is a focused reference pass, not a reconstruction
of the game's implementation or a personal playtest.

## Developer evidence

**Dave Levy / UploadVR, 11 January 2024.** The original idea was to put a mech
between the player and physical contact: the player's movements drive the
machine, so its impacts need not feel like impacts on their real arms. Levy
also explains why arm locomotion suits their metal-gorilla brawler fantasy.
This supports separating tracked hands from actuated arms, but their movement
choice does not settle our seated space-flight controls.
[Interview](https://www.uploadvr.com/underdogs-vr-interview/)

**Dave Levy / VR陀螺, 30 June 2024 (Chinese interview).** Paraphrased in English:
the pilot's visible arms can match real tracking while the mech arms interact
with the physical world. He describes rating punches using speed and swing
extent, then strengthening damage, impact and audiovisual feedback. This is
useful evidence that the effect is deliberately authored around input rather
than determined only by simulation. He also acknowledges that stick-driven
movement can fit some mech types; this game's priority was bodily action.
[Interview](https://www.vrtuoluo.cn/540265.html)

**Yotam Harris / gamescom dev 2026.** The official listing for “Responsive
Physics in VR: Preserving Player Intent in UNDERDOGS,” dated 25 August 2026,
explicitly mentions responsive physics limbs, input history, punch/throw intent,
effort-based impacts and depth-perception compensation. I found the session
abstract, not its slides/video or implementation details. It is a promising
technical lead, not evidence of specific algorithms or tuning constants.
[Official session listing](https://bizcommunity.gamescom.global/event/gamescom-biz-2026/planning/UGxhbm5pbmdfNDQ4NjQzNQ%3D%3D)

## First-hand impressions

Virtual Grip's 24 January 2024 review describes calibrating the mech at the
start, then controlling its large arms with physical movements. The reviewer
found the arm locomotion natural after the tutorial. This is useful testimony
about learnability; phrases such as “mirror” do not establish literal one-to-one
spatial gain or prove the absence of servo limits.
[Review](https://virtual-grip.com/underdogs-review/)

## What remains unknown

These sources do not specify the hand-to-arm position gain, quaternion mapping,
servo constants, constraints, calibration transform, or whether/how a cockpit
control can be released and regrabbed. They do not establish a choice between
free reattachment, a fixed orientation reference, or grip-to-park interaction.
Our experiment below is our own response to the user's feedback, not a claim
that UNDERDOGS implements it.

## Application to this prototype

Maintain three distinct poses: physical controller tracking, the cockpit-local
parked/held control, and the bounded external arm. Show each honestly rather
than moving the pilot's tracked hand to hide actuator lag. The requested live
comparison keeps position rebasing in both cases and compares held-angle
preservation against a cockpit-relative orientation reference.

Flight posing is also a separate experiment. The hologram provides a humanoid
body, shoulders and limbs whose spine tends toward requested acceleration;
coasting can retain a velocity-aligned flight pose while exhaust switches off.
A bounded body turn cannot immediately align its main jet with every braking
or lateral command, so a residual vernier visual accounts for the remaining
acceleration direction. This is an animation explanation, not a torque model,
energy model, realistic thruster-placement solution or cockpit rotation command.

The lesson I would carry over from the interviews is consistent representation:
tracking remains direct, the commanded machine may lag or hit a limit, and the
fiction/visuals explain the difference. The live toggles are there to test which
version feels understandable here; the sources cannot choose that for us.
