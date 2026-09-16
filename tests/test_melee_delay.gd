extends SceneTree
const Delay = preload("res://scripts/melee_delay.gd")
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var d := Delay.new()
	d.reset({"target":0},{"pose":0})
	d.send_input({"target":1})
	check(d.receive_input().target == 1, "zero delay input immediate")
	d.send_snapshot({"pose":1})
	check(d.receive_snapshot().pose == 1, "zero delay state immediate")
	check(d.configure(200,{"target":1},{"pose":1}), "configure 200ms RTT")
	var command := {"target":2,"nested":{"x":3}}
	d.send_input(command)
	command.nested.x = 99
	d.advance(.099)
	check(d.receive_input().target == 1, "input holds before 100ms outbound delay")
	d.advance(.001)
	var delivered := d.receive_input()
	check(delivered.target == 2 and delivered.nested.x == 3, "input arrives at half RTT and isolates mutation")
	d.send_snapshot({"pose":2})
	d.advance(.099)
	check(d.receive_snapshot().pose == 1, "committed response holds during return delay")
	d.advance(.001)
	check(d.receive_snapshot().pose == 2, "committed response arrives at full RTT")
	# Arriving state is held, never extrapolated; callers cannot mutate it.
	var shown := d.receive_snapshot()
	shown.pose = 99
	d.advance(1.0)
	check(d.receive_snapshot().pose == 2, "no prediction or mutable presentation alias")
	d.send_input({"target":3})
	d.send_input({"target":4})
	d.advance(.2)
	check(d.receive_input().target == 4 and d.queued_counts().x == 0, "long tick consumes due states without stale burst")
	d.send_input({"target":5})
	d.send_snapshot({"pose":5})
	var seq: int = d.input_sequence
	check(d.configure(100,{"target":6},{"pose":6}), "live delay change reseeds")
	d.advance(1)
	check(d.receive_input().target == 6 and d.receive_snapshot().pose == 6, "old queues cannot arrive after slider change")
	check(d.input_sequence >= seq, "sequences monotonic across delay changes")
	d.send_input({"target":7})
	check(not d.configure(100,{},{}), "unchanged slider does not clear pending input")
	d.advance(.05)
	check(d.receive_input().target == 7, "unchanged setting retains packet")
	for i in 1000:
		d.send_input({"target":i})
		d.send_snapshot({"pose":i})
	check(d.queued_counts() == Vector2i(512,512), "bounded both queues")
	d.flush({"target":0},{"pose":0})
	d.advance(5)
	check(d.receive_input().target == 0 and d.receive_snapshot().pose == 0, "pause/reset flush prevents stale resumption")
	d.reset()
	check(d.clock == 0 and d.input_sequence == 0 and d.queued_counts() == Vector2i.ZERO, "reset clears counters and queues")
	check(not d.configure(NAN,{},{}), "invalid delay rejected")
	print("MELEE_DELAY_TEST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
