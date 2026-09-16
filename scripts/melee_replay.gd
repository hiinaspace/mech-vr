class_name MeleeReplay
extends RefCounted
## Resolved-state replay. Playback never runs the physics solver again.
const VERSION := 1
const SAMPLE_RATE := 30.0
const MAX_FRAMES := 601
const MAX_BYTES := 32 * 1024 * 1024
const MAX_ANNOTATIONS := 200
var replaying := false
var playing := false
var cursor := 0.0
var annotations: Array = []
var metadata: Dictionary = {}
var last_error := ""
var _frames: Array = []
var _clip: Array = []
var _clock := 0.0
var _next_sample := 0.0
var _pending_events: Array = []

func record(delta: float, snapshot: Dictionary) -> void:
	if replaying or not is_finite(delta) or delta < 0.0:
		return
	_clock += delta
	# Preserve short contact events between the 90 Hz physics / 30 Hz replay ticks.
	if snapshot.get("events") is Array:
		for event in snapshot.events:
			if _pending_events.size() < 128:
				_pending_events.append(event.duplicate(true) if event is Dictionary or event is Array else event)
	if _clock + 0.000001 < _next_sample:
		return
	var state := snapshot.duplicate(true)
	if snapshot.has("events"):
		state.events = _pending_events.duplicate(true)
	_pending_events.clear()
	_frames.append({"time": _clock, "state": state})
	# Long stalls produce one observed state, never invented duplicate history.
	_next_sample = _clock + 1.0 / SAMPLE_RATE
	while _frames.size() > MAX_FRAMES or (_frames.size() > 1 and _clock - float(_frames[0].time) > 20.0):
		_frames.pop_front()

func frame_count() -> int:
	return _frames.size()

func begin_replay() -> bool:
	if _frames.is_empty():
		return false
	_clip = _frames.duplicate(true)
	var origin: float = _clip[0].time
	for frame in _clip:
		frame.time -= origin
	annotations.clear()
	replaying = true
	playing = false
	cursor = duration()
	return true

func end_replay() -> void:
	replaying = false
	playing = false

func duration() -> float:
	return 0.0 if _clip.is_empty() else float(_clip[-1].time)

func toggle_playing() -> void:
	if not replaying:
		return
	if not playing and cursor >= duration():
		cursor = 0.0
	playing = not playing

func scrub(seconds: float) -> void:
	if is_finite(seconds):
		cursor = clampf(seconds, 0.0, duration())
	playing = false

func advance(delta: float) -> void:
	if replaying and playing and is_finite(delta) and delta >= 0.0:
		cursor = minf(cursor + delta, duration())
		if cursor >= duration():
			playing = false

func sample() -> Dictionary:
	if _clip.is_empty():
		return {}
	for index in range(1, _clip.size()):
		if float(_clip[index].time) > cursor:
			var a: Dictionary = _clip[index - 1]
			var b: Dictionary = _clip[index]
			var weight := (cursor - float(a.time)) / (float(b.time) - float(a.time))
			return _interpolate(a.state, b.state, weight)
	return _clip[-1].state.duplicate(true)

func add_annotation(value: String) -> bool:
	var clean := value.strip_edges().left(1000)
	if not replaying or clean.is_empty() or annotations.size() >= MAX_ANNOTATIONS:
		return false
	annotations.append({"time": cursor, "text": clean})
	return true

func save_file(path: String, build_info: Dictionary = {}) -> Error:
	last_error = ""
	if _clip.is_empty():
		return _fail("No replay clip has been captured.", ERR_UNAVAILABLE)
	if not _supported(_clip) or not _supported(build_info):
		return _fail("Replay contains unsupported or nonfinite values.", ERR_INVALID_DATA)
	var document := {"format": "mech-vr-resolved-replay", "version": VERSION,
		"sample_rate": SAMPLE_RATE, "metadata": _encode(build_info),
		"frames": _encode(_clip), "annotations": annotations}
	var content := JSON.stringify(document)
	if content.to_utf8_buffer().size() > MAX_BYTES:
		return _fail("Replay exceeds 32 MiB limit.", ERR_OUT_OF_MEMORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK:
		return _fail("Cannot create replay directory.", directory_error)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _fail("Cannot write replay file.", FileAccess.get_open_error())
	file.store_string(content)
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return _fail("Replay write failed.", write_error)
	metadata = build_info.duplicate(true)
	return OK

func load_file(path: String) -> Error:
	last_error = ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Cannot open replay file.", FileAccess.get_open_error())
	if file.get_length() > MAX_BYTES:
		return _fail("Replay exceeds 32 MiB limit.", ERR_INVALID_DATA)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or parsed.get("format") != "mech-vr-resolved-replay" or parsed.get("version") != VERSION:
		return _fail("Unsupported or invalid replay document.", ERR_INVALID_DATA)
	var frames = _decode(parsed.get("frames"))
	var info = _decode(parsed.get("metadata"))
	var notes = parsed.get("annotations")
	if not last_error.is_empty() or not frames is Array or frames.is_empty() or frames.size() > MAX_FRAMES or not info is Dictionary or not notes is Array or notes.size() > MAX_ANNOTATIONS:
		return _fail("Invalid replay contents.", ERR_INVALID_DATA)
	var previous := -1.0
	for frame in frames:
		if not frame is Dictionary or not frame.get("state") is Dictionary or not _number(frame.get("time")):
			return _fail("Invalid replay frame.", ERR_INVALID_DATA)
		var time := float(frame.time)
		if time < 0.0 or time <= previous or time > 20.001:
			return _fail("Replay timestamps are outside the ordered 20 second clip.", ERR_INVALID_DATA)
		previous = time
	if absf(float(frames[0].time)) > 0.000001:
		return _fail("Replay must start at zero.", ERR_INVALID_DATA)
	for note in notes:
		if not note is Dictionary or not _number(note.get("time")) or not note.get("text") is String:
			return _fail("Invalid annotation.", ERR_INVALID_DATA)
		if note.time < 0.0 or note.time > previous or note.text.length() > 1000:
			return _fail("Annotation outside clip limits.", ERR_INVALID_DATA)
	# Commit only after full validation so a bad file does not replace the clip.
	_clip = frames
	metadata = info
	annotations = notes
	replaying = true
	playing = false
	cursor = 0.0
	return OK

func _fail(message: String, error: Error) -> Error:
	last_error = message
	return error

func _interpolate(a: Variant, b: Variant, weight: float) -> Variant:
	if typeof(a) != typeof(b):
		return a
	if a is Transform3D:
		# Hidden visual leaves use zero scale; no quaternion exists for that basis.
		if absf(a.basis.determinant()) < 0.000001 or absf(b.basis.determinant()) < 0.000001:
			return a
		return a.interpolate_with(b, weight)
	if a is Basis:
		if absf(a.determinant()) < 0.000001 or absf(b.determinant()) < 0.000001:
			return a
		return Transform3D(a, Vector3.ZERO).interpolate_with(Transform3D(b, Vector3.ZERO), weight).basis
	if a is Vector3:
		return a.lerp(b, weight)
	if a is float:
		return lerpf(a, b, weight)
	if a is Dictionary:
		var result: Dictionary = a.duplicate(true)
		for key in a:
			# Contacts/events represent observed solver records, not blended guesses.
			if b.has(key) and key != "contacts" and key != "events":
				result[key] = _interpolate(a[key], b[key], weight)
		return result
	if a is Array and a.size() == b.size():
		var result: Array = []
		for index in a.size():
			result.append(_interpolate(a[index], b[index], weight))
		return result
	return a

func _encode(value: Variant) -> Variant:
	if value is int:
		return {"$type": "int", "value": [str(value)]}
	if value is Basis:
		return {"$type": "Basis", "value": [_encode(value.x), _encode(value.y), _encode(value.z)]}
	if value is Transform3D:
		return {"$type": "Transform3D", "value": [_encode(value.basis.x), _encode(value.basis.y), _encode(value.basis.z), _encode(value.origin)]}
	if value is Vector3:
		return {"$type": "Vector3", "value": [value.x, value.y, value.z]}
	if value is Dictionary:
		var pairs: Array = []
		for key in value:
			pairs.append([str(key), _encode(value[key])])
		return {"$type": "Dictionary", "value": pairs}
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_encode(item))
		return result
	return value

func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func _decode(value: Variant, depth: int = 0) -> Variant:
	if depth > 24:
		last_error = "Replay nesting limit exceeded."
		return null
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_decode(item, depth + 1))
		return result
	if value is Dictionary:
		var fields = value.get("value")
		if not fields is Array:
			last_error = "Invalid replay type encoding."
			return null
		match value.get("$type"):
			"int":
				if fields.size() == 1 and fields[0] is String and fields[0].is_valid_int():
					return int(fields[0])
			"Dictionary":
				var result := {}
				for pair in fields:
					if not pair is Array or pair.size() != 2 or not pair[0] is String:
						last_error = "Invalid dictionary encoding."
						return null
					result[pair[0]] = _decode(pair[1], depth + 1)
				return result
			"Vector3":
				if fields.size() == 3 and _number(fields[0]) and _number(fields[1]) and _number(fields[2]):
					return Vector3(fields[0], fields[1], fields[2])
			"Basis":
				var decoded = _decode(fields, depth + 1)
				if decoded.size() == 3 and decoded[0] is Vector3 and decoded[1] is Vector3 and decoded[2] is Vector3:
					return Basis(decoded[0], decoded[1], decoded[2])
			"Transform3D":
				var decoded = _decode(fields, depth + 1)
				if decoded.size() == 4 and decoded[0] is Vector3 and decoded[1] is Vector3 and decoded[2] is Vector3 and decoded[3] is Vector3:
					return Transform3D(Basis(decoded[0], decoded[1], decoded[2]), decoded[3])
		last_error = "Unknown or malformed replay type."
		return null
	if value == null or value is bool or value is String or _number(value):
		return value
	last_error = "Unsupported replay value."
	return null

func _supported(value: Variant, depth: int = 0) -> bool:
	if value is Basis:
		return value.is_finite()
	if depth > 24:
		return false
	if value is Transform3D:
		return value.is_finite()
	if value is Vector3:
		return value.is_finite()
	if value is Dictionary:
		for key in value:
			if not key is String or not _supported(value[key], depth + 1):
				return false
		return true
	if value is Array:
		for item in value:
			if not _supported(item, depth + 1):
				return false
		return true
	return value == null or value is bool or value is String or _number(value)
