class_name MeleeDelay
extends RefCounted
## Deterministic latency comparison, not networking or prediction. Caller ticks
## once per simulation step, sends actuator intent outbound, and sends committed
## solved state inbound. Head tracking and cockpit UI must bypass this helper.
const MAX_RTT_MS := 2000.0
const MAX_QUEUE := 512
var rtt_ms := 0.0
var clock := 0.0
var input_sequence := 0
var snapshot_sequence := 0
var _sequence := 0
var _inputs: Array = []
var _snapshots: Array = []
var _input: Dictionary = {}
var _snapshot: Dictionary = {}

func configure(milliseconds: float, seed_input: Dictionary, seed_snapshot: Dictionary) -> bool:
	if not is_finite(milliseconds):
		return false
	var requested := clampf(milliseconds, 0.0, MAX_RTT_MS)
	if is_equal_approx(requested, rtt_ms):
		return false
	rtt_ms = requested
	flush(seed_input, seed_snapshot)
	return true

func flush(seed_input: Dictionary = {}, seed_snapshot: Dictionary = {}) -> void:
	# Keep time and sequence monotonic across live slider changes. Both queues
	# disappear together: no old target or old presentation can arrive afterward.
	_inputs.clear()
	_snapshots.clear()
	_input = seed_input.duplicate(true)
	_snapshot = seed_snapshot.duplicate(true)
	input_sequence = _sequence
	snapshot_sequence = _sequence

func reset(seed_input: Dictionary = {}, seed_snapshot: Dictionary = {}) -> void:
	clock = 0.0
	_sequence = 0
	flush(seed_input, seed_snapshot)

func advance(delta: float) -> void:
	if is_finite(delta) and delta >= 0.0:
		clock += delta

func send_input(command: Dictionary) -> int:
	return _send(_inputs, command)

func send_snapshot(committed_state: Dictionary) -> int:
	return _send(_snapshots, committed_state)

func _send(queue: Array, state: Dictionary) -> int:
	_sequence += 1
	queue.append({"due": clock + rtt_ms / 2000.0, "sequence": _sequence, "state": state.duplicate(true)})
	if queue.size() > MAX_QUEUE:
		queue.pop_front()
	return _sequence

func receive_input() -> Dictionary:
	var delivery := _receive(_inputs)
	if not delivery.is_empty():
		_input = delivery.state
		input_sequence = delivery.sequence
	return _input.duplicate(true)

func receive_snapshot() -> Dictionary:
	var delivery := _receive(_snapshots)
	if not delivery.is_empty():
		_snapshot = delivery.state
		snapshot_sequence = delivery.sequence
	return _snapshot.duplicate(true)

func _receive(queue: Array) -> Dictionary:
	var newest: Dictionary = {}
	while not queue.is_empty() and float(queue[0].due) <= clock + 0.000000001:
		newest = queue.pop_front()
	# States replace states. A long frame never replays a burst of stale commands.
	return newest

func queued_counts() -> Vector2i:
	return Vector2i(_inputs.size(), _snapshots.size())
