# Melee greybox: contact, propulsion and heat

Research date: 2026-09-15. Research informed the subsequently authorized contact
lab. See [the test card](melee-headset-test.md) for implemented scope and
[verification](melee-verification.md) for evidence. Heat, damage and multiplayer
remain future experiments. PvP versus cooperative PvE remains an open decision.
The user subsequently supplied the original conversation notes, emphasizing
readable resistance, opponent proprioception and replay with annotations.

## Direction

The promising question is: **can the pilot deliberately control a contact by
combining blade placement, arm compliance and suit thrust?** A useful success
looks like choosing to hold, slide, yield, disengage or boost through contact,
and understanding why the chosen action worked.

User clarification: start with the Gundam-inspired rule that blades resist one
another, while shields and robot structure can gradually burn through. This is
the prototype's material contract, not a claim that all Gundam continuities or
heated axes have identical mechanics. Heated solid weapons remain an interesting
later comparison.

The user's closest comparison is Swords of Gurrah, particularly its damage/block
modes and break cooldown. They describe Blade & Sorcery and Boneworks/Bonelab
as having goofy melee physics, with short slow-motion abilities partly making
up for it; GORN leans into waggling. These are the user's reported experiences,
not findings from gameplay testing in this task. They have not played Ironlights.
This makes stable, legible contact at normal speed a useful first contrast.
Slow motion can support replay and diagnosis without becoming a prerequisite
for the interaction. Boxing is an adjacent reference, but does not establish
that sustained blade pressure and sliding can be read without force feedback.

Still open: cockpit response to external torque. The initial discussion proposes
finite attitude stabilization as one comparison; it is not a settled comfort
decision.

## Evidence and current project boundary

- Read both initial implementation documents and the project reference inventory.
- Read all visible messages in the supplied [Claude discussion](https://claude.ai/share/4604c4bb-c5dc-4701-91c7-c00f4a1aaa27).
  Its original attachment is hidden. Later user messages explicitly prefer
  continuous guards/cuts over discretizing fencing into named guard states, and
  emphasize bind feedback, replay and positioning.
- The durable checkout `/home/s/code/mech-vr` is the original planning branch at
  `4058553`. The accepted MVP is in `/home/s/.codex/worktrees/3d5e/mech-vr`,
  clean `codex/m0a` at `9b410cf17e22e6c402737169776aa4e5cea352fd` when inspected.
- In that worktree, `scripts/main.gd` assigns a `CharacterBody3D` its velocity
  and orientation; `scripts/control_model.gd` moves the arm transforms through
  speed/acceleration limits. `scripts/range_world.gd:sword_sweep` detects passage
  through target parts and debounces hits. None of these applies blade contact
  forces to an articulated robot. Physics ticks are configured at 90 Hz.
- The exterior chest/posture is a visual solution around actual equipment
  endpoints. It is not an inertial body with physically placed thrusters.
  See the worktree's `docs/playtest-notes.md` and
  `docs/research/space-body-posture.md`. A physical prototype must give each
  transform one owner; existing visual posture must not overwrite physics.
- Prim at `/home/s/code/prim`, HEAD `015ce987b14f23e844a81013eab05669c037c586`,
  was inspected read-only. Its unrelated untracked
  `docs/BETA_PLAYBACK_FOLLOWUP_PLAN.md` was preserved. Network/voice observations
  below come from current source and `docs/PROTOCOL.md`, not rerun tests.
- No games were launched, gameplay videos judged, or headset tests performed
  during this research. The org tracker records an earlier GPU reset-required
  failure; that historical environment state was not refreshed here.

## What the references contribute

| Reference | Grounded contribution | Proposed use here |
| --- | --- | --- |
| [Ringeck translations and source witnesses](https://wiktenauer.com/wiki/Sigmund_ain_Ringeck) | Distinguish leverage along the blade and responding to hard/soft opposition, including winding and leaving contact. | Test different contact locations, rotations and yielding; avoid a single winning-pressure meter deciding the result. |
| [Dimicator: binding from Second Ward](https://www.patreon.com/Dimicator/posts/i-33-how-to-bind-32650483) | The instructor's description explains hand inversion and pressure-testing a sword-and-buckler interpretation. | A concrete study lead for actions to demonstrate with a friend. The linked video's motion was not evaluated here. |
| [Blade & Sorcery developer](https://www.warpfrog.com/) | Describes freely interacting, physics-based VR combat. | Reference for freedom/contact expectations; this does not demonstrate balanced competitive binds. |
| [Hellish Quart developer description](https://www.hellishquart.com/presskit) | Active ragdolls, physical blade blocking and authored fencing motion, with a local multiplayer focus. | Useful separation of a controller's intent from the motion allowed by contact. Our tracking input can replace authored attack selection. |
| [Ironlights developer store description](https://store.steampowered.com/app/1245950/Ironlights/) | Weapons shatter on impact and reload behind the player. | An alternate way to end the hand/weapon mismatch. It removes the persistent contact we want to investigate. |
| [Swords of Gurrah developer store description](https://store.steampowered.com/app/833090/Swords_of_Gurrah/) | Weapons shatter and regrow on collisions; online multiplayer is part of the design. | Another example of deliberately defining contact rules around VR. Detailed hardening rules from the old chat are not needed as unverified implementation assumptions. |
| [Until You Fall GDC talk](https://media.gdcvault.com/gdc2020/presentations/Until_You_Fall_Bennett_Dave_Jalbert_Patrick.pdf) | Choreographed combat, deliberate weapon response, and incentives against the smallest effective waggle; many secondary interactions were cut. | Borrow feedback discipline and observe what players actually optimize. Do not require its choreographed blocking rules. |
| [CHAI3D finger proxy](https://chai3d.org/download/doc/html/chapter9-mesh.html) | Separates a physical input goal from a constrained virtual proxy, connected by a virtual spring. | Useful conceptual model for commanding an external robot arm. Actual force-feedback hardware results do not prove vibration/visual substitution works here. |
| [Stable PD controllers, Tan/Liu/Turk](https://www.jie-tan.net/project/spd.html) | An implicit-style controller formulation improves numerical stability at high gains. | Investigate stable force control; numerical stability is distinct from choosing finite actuator strength and a readable response. |
| [Networked Physics in VR, Fiedler](https://www.gafferongames.com/post/networked_physics_in_virtual_reality/) | Demonstrates state synchronization with Unity/PhysX despite non-determinism and discusses interaction authority and timing. | Evidence that non-determinism is not an impossibility result. Cube interactions do not validate competitive sword contacts. |

Two corrections to the earlier discussion matter. It does not establish that
most real fencing consists of prolonged binds, or that a bind can be faithfully
resolved from one pressure scalar. Nor does [Hellish Quart's FAQ](https://www.hellishquart.com/faq)
establish a universal impossibility of online rigid-body physics. Its technical,
staffing and product constraints are specific to that project.

## Physical contract

### Keep input prompt and the robot finite

Tracked cockpit hands stay responsive. Their poses command a reachable external
grip pose. A motor tries to achieve that pose with bounded force, torque and
speed; actual weapon motion follows the simulation. The blade can stop even
while the pilot moves a controller onward.

For intuition, a position servo asks for a force like
`F = clamp(Kp * position_error + Kd * velocity_error, Fmax)`, with a corresponding
orientation/torque controller. This is a description, not a tested numerical
implementation. Derivatives must use consistent moving frames, and physics
step size, stiffness, damping and inertia need joint tuning.

Important distinctions:

- Command error is an input to a virtual actuator, not a measurement of the
  user's muscle force. Controller tracking cannot measure that force.
- Greater robot mass alone does not define slower response: force/mass and
  torque/inertia do. Zero gravity removes weight, not inertia.
- The beam's visible length need not imply the mass distribution of a steel
  rod. Arm/hilt inertia and field contact resistance are separate parameters.
- Cap large target errors and controller output. Avoid integral windup or
  accumulating an enormous spring release when the obstruction disappears.
  Tracking recovery and UI/handle reattachment must not create a combat impulse.
- A parked arm keeps a target with finite holding strength. It must not become
  an infinitely stiff shield mount merely because the pilot releases a handle.

### A small coupled model is enough to test the idea

Start with a dynamic torso and dynamic grip/weapon proxies, driven relative to
the torso. Visual arm segments can follow the solved endpoints. Motors need
equal/opposite internal reactions, including the complete lever-arm torque,
so pushing the weapon can push or twist the suit. Driving a weapon toward a
world-space target without transmitting the reaction would bypass the hypothesis.

This reduced model omits changing arm mass distribution and individual joint
loads. It can establish whether suit/weapon coupling matters before adding
shoulder, elbow, wrist, pelvis and leg bodies. Add one physical arm chain only
if endpoint control cannot express the desired leverage, reach or failure.

Use a bounded flight controller over the dynamic torso. First test total force
and torque limits. Then, if directional bracing matters, allocate the request
to a small explicit set of thrusters: each supplies a force along its own axis
at its own position and therefore contributes `r cross F` torque. Account for
thrust saturation rather than directly assigning a desired body velocity.

Full internal joints are not a prerequisite for an actual thruster allocator.
Conversely, a rigid body with unlimited attitude control will conceal most of
the torque/contact behavior even if the rest is physically simulated.

[Godot's Jolt documentation](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html)
lists joint-interface differences and unsupported tuning properties. Verify
the locally installed version and the exact motor behavior in a small scene
before selecting an extension or building a full rig.

### Contact has direction and an exit

Use actual blade geometry and contact location, relative linear/angular motion,
motor limits and contact friction. A bind is a period of contact, not a welded
joint or mandatory combat mode. Rotation, lateral movement, or withdrawal must
be able to change or end it.

The contact normal determines which motion is blocked. Tangential resistance
determines whether blades slide or remain engaged. The same contact force
produces different torques depending on its distance from each grip. Motor
strength, inertia and configuration then determine who yields. Near-hilt
contact should not receive an unexplained universal damage/priority bonus.

For fictional beam fields, tangential friction is a design parameter. Compare
slippery versus modestly resistant contact; do not assume sharp-steel binding
properties or make contact so sticky that winding is impossible. A round beam
also does not have the cutting edges and guard geometry of a HEMA longsword.

Thin, long blades need collision testing for angular sweeps as well as linear
travel. The present target-hit sweep is useful instrumentation, not a blade
response solver. Solver contact, swept detection and rendered geometry must
agree, including during moving-target and high-closing-speed cases.

### What the pilot can read

Begin with an impact haptic, contact-local effect, visible deflection and an
actuator-load sound. Add an optional intended-grip marker/short error tether
and direction indicator if users cannot tell why the actual weapon is blocked.
Keep contact load, heat and imminent damage distinguishable. A glowing blade
alone should not ambiguously mean all three.

The existing cockpit miniature is especially useful: it can show whole-suit
displacement, attitude corrections and active thrusters while the pilot watches
the blade. A small replay buffer should record solved poses, commands and
contacts, then offer both cockpit and external playback. Record resolved states
so replay does not depend on a nondeterministic resimulation matching exactly.

Leave HMD tracking live even during pauses or replay. Prefer tunable actuator
response and local training slow motion initially; global multiplayer time
dilation introduces unrelated questions about projectiles and third parties.

## Proposed experiments, each with a decision

These are experiments to choose between, not an authorization to implement all
of them. Keep one scenario fixed while changing one property.

| Experiment | Setup and deliberate action | What would earn the next step? |
| --- | --- | --- |
| 1. Read contact | One sword against a fixed slab, then a motor-driven blade. Push, slide, withdraw, release and recontact. | The pilot can predict the blade's stopping/deflection and recover without chasing a misleading target. No tunneling or violent catch-up. |
| 2. Brace in space | The same contact with free-floating bases and finite attitude/thrust control. Change opponent mass, motor force and thruster budget separately. | Bracing, yielding or translating around contact changes the outcome in an understandable way. Contact does not just become an unstable spring fight. |
| 3. Defeat a simple defense | A guard-holding bot, then a bot making one repeated telegraphed cut through the same finite actuator model. Try an intercept, slide, wind or withdrawal/counter. | More than one deliberate solution works, and failed actions are explainable. The bot must be displaceable; an animated infinite-strength sword is a misleading opponent. |
| 4. Place heat | A small tiled shield with local temperature and irreversible ablation. Attacker holds one spot; defender shifts fresh material or redirects the blade. | Geometry and dwell create a choice before adding whole-body systems. Cooling does not repair ablation. |
| 5. Meet a friend | Shared room, voice, poses, reset and replay; then authoritative mutual contact with imposed delay. Swap host roles. | Both players can describe the same exchange; input lag and corrections do not erase the successful solo interaction. |
| 6. Mix range and melee | Begin outside reach with one rifle, shield and saber; fixed approach distances and closing speeds. | There is a reason to engage, remain close or disengage, and a skilled interception survives plausible boost speeds. |

Free space changes the balance rather than solving abuse. Test static
blade-first boosting, shield ramming, tiny repeated contact motions, permanent
maximum-force holds, double hits and disengage-and-shoot. A fair-looking
cooperative demonstration is not evidence that these strategies are dominated.

Use relative velocity and stopping distance for approach training. Without
enough time inside reach, encounters become fly-by jousts regardless of arm
precision. Stabilization and explicit matched-velocity assistance could create
longer exchanges, but any assistance should be a visible, separate comparison.

Avoid choosing the combined combat economy too early. Possible reasons for
melee include cover, shield protection against ranged fire, exposed subsystems,
or close defense of an objective. Start close for contact research, then test
the approach separately; the first test cannot establish a reason to close range.

## Heat and damage without a full material simulation

The first shield can be a modest grid, for example 4 by 4 or 8 by 8 patches.
Each patch stores temperature/thermal energy and remaining material. Integrate
deposited beam power over actual contact time, with bounded total weapon output;
do not multiply power by the number of solver points or overlapping tiles.
Higher temperature can increase ablation or reduce material strength. Material
loss is persistent until reset; adjacent patch conduction can be added later.

Beam contact can damage at zero relative speed. This makes maintaining contact
an intended attack, rather than a waggle exploit. Mechanical impact and friction
can add separately, but impact speed is not the sole basis of beam damage.
Later, a solid axe can use edge alignment and mechanical cutting/impact along
with heat. Giving both weapons one generic swing score would erase the contrast.

For a first suit thermal model, use a few thermal masses: hot machinery,
weapon assembly, shield patches and radiators. A node follows an energy balance:

`C_i * dT_i/dt = waste_heat_i + absorbed_heat_i - transferred_heat_i - radiated_heat_i`

`C_i` is heat capacity in joules per kelvin; the right-hand terms are powers
in watts. A passive connection can transfer heat according to a conductance
times temperature difference. For a simple gray radiator facing an effective
cold background, use `P_rad = emissivity * sigma * area * (T^4 - T_sink^4)`.
Temperatures are absolute. This toy model omits detailed view factors and
spectral/material behavior; tune timescales for the desired exchange length.
[NASA thermal-control overview](https://www.nasa.gov/smallsat-institute/sst-soa/thermal-control/)
grounds the energy-balance approach.

Separate power, temperature and damage. Available power can limit simultaneous
actuation; temperature records accumulated waste heat; damage records lasting
loss. Do not assume all thruster energy stays in the suit as heat, or that a
stalled arm generates none just because its mechanical velocity is zero.
Treat losses and limits as explicit authored models until better data is needed.

Three visually useful choices follow:

1. **Expose radiators:** more effective cooling area, more exposed equipment.
2. **Run hot:** greater radiative loss, reduced thermal margin. Hot fins need
   not mean the entire suit is close to failure.
3. **Dump hot material:** a finite coolant or heat-store discharge buys a short
   burst. Ejecting a radiator removes only the energy in the ejected assembly
   and reduces future cooling capacity; it does not reset body temperature.

[Children of a Dead Earth's radiator article](https://childrenofadeadearth.wordpress.com/2016/04/25/why-does-it-look-like-that-part-3/)
is particularly useful for visibly different temperature loops and the
protection/cooling tradeoff. Its restriction on radiator temperature describes
a passive heat path. A radiator hotter than the component being cooled requires
an active heat pump with an energy cost, or a separate hotter source loop; merely
pumping coolant does not provide that temperature lift. Keep the human cockpit
on a cool loop. Glowing reactor/thruster radiators and an isolated cockpit are
compatible fictional machinery choices.

For system damage, try one discrete consequence first: a lost radiator segment,
weakened wrist actuator or disabled vernier. Predefined detachable parts can
later change inertia, available thrust and coolant connectivity. Arbitrary
mesh slicing is a separate engineering problem and is unnecessary to see if
losing a subsystem produces an interesting recovery decision.

Watch the heat death spiral: if overheating simultaneously removes movement,
defense and offense, there may be no meaningful recovery action. A limited
reserve for retreat or emergency cooling is a design option worth comparing.

## Prim reuse and the network experiment

Current Prim has a native Iroh endpoint, authenticated shared-secret discovery,
bounded reliable control traffic, lossy sequenced pose/voice traffic, and audio
capture/playout independent of the Godot main thread. Its native session uses
`godot_network_audio::{AudioStreamNetwork, NetworkAudioSender}`; the reusable
audio dependency includes Opus/NetEq components. Those are concrete starting
points for friend co-presence and voice, not a finished combat networking layer.

Prim's current avatar pose snapshot is 636 bytes at 20 Hz; receivers smooth
targets and solve bodies locally. That is a social/avatar format, not an
authoritative blade contact state. Its single host orders media playback, not
physics. See `/home/s/code/prim/docs/PROTOCOL.md`, `native/src/network.rs`,
`native/src/session.rs`, `Cargo.toml`, and the `godot-network-audio` dependency.

Extract the small room/audio boundary with a distinct application protocol and
discovery namespace. Keep media, launcher and avatar/viseme requirements out
of the first mech room. Voice can initially act as clear cockpit radio; importing
Prim's avatar-distance attenuation unchanged might make nearby giant-robot
pilots unnecessarily hard to hear. Preserve mute/device controls.

For first mutual contact, use one authoritative host for both contacting suits,
weapons and damage, with sequenced/timestamped commands from clients. Keep that
authority through a contact; handing each blade to a different independent
authority creates disagreement precisely where the two interact. Sample and
present actual combat poses with consistent times; do not collide against a
separately delayed social avatar.

First establish correct host snapshots and measure the remote control cost.
Prediction/reconciliation can then improve response, with corrections applied
to physics and smoothed presentation distinguished carefully. Stock engine
deterministic lockstep is not assumed. Local prediction, visual smoothing and
latency buffers have different tradeoffs; none removes missing information.
[Fiedler's state-synchronization article](https://www.gafferongames.com/post/state_synchronization/)
provides the relevant distinction.

A bounded test could compare 0, 50, 100 and 200 ms imposed **round-trip** delay,
then add jitter/loss separately and record actual measured RTT. These are test
conditions, not supported-latency claims. Repeat with each person hosting.
Record authoritative contact, each client's displayed contact, pose error and
correction magnitude. A sustained bind gives time to react but can also amplify
corrections; the initial parry remains sensitive to latency.

Basic shared poses and voice can precede sophisticated AI. Once the local
contact fixture is intelligible, a friend is likely a better source of novel
guards, feints and explanations than a broad AI implementation. A simple
repeatable bot remains valuable for regression and practicing one action.

## Practical first choice

Recommend choosing one short contact session with:

- the existing sword grip and shield mapping;
- a fixed fixture and a free-floating powered opponent;
- finite arm forces plus a finite suit stabilizer;
- contact/actuator feedback and a small replay buffer;
- optional local shield burn-through only after basic resistance is readable.

The decisive question is whether the pilot can intentionally use an angle,
yield or thruster input to change a contact outcome. A spectacular clash alone
does not settle this. Physical headset response, two-person feedback and
eventual ranged approach each remain separate observations.
