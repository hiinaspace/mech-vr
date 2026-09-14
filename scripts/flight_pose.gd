extends RefCounted
## Authored visual approximation in cockpit axes (+Y spine, -Z forward).
## No forces or physics state are changed. Inputs must exclude collision impulses.
const MAX_LEAN := deg_to_rad(75.0)
const TURN_RATE := deg_to_rad(65.0)
const DIRECTION_DEADBAND := deg_to_rad(10.0)
const DIRECTION_DWELL := .22
var body_basis := Basis.IDENTITY
var main_acceleration := 0.0
var residual_acceleration := Vector3.ZERO
var flight_amount := 0.0
var mode := "IDLE"
var _direction := Vector3.UP
var _candidate := Vector3.UP
var _candidate_time := 0.0
var _thrust_active := false
var _moving := false
var _idle_time := 0.0

func step(dt: float, velocity: Vector3, acceleration: Vector3, paused := false) -> void:
	if not velocity.is_finite() or not acceleration.is_finite() or not is_finite(dt):
		main_acceleration = 0.0
		residual_acceleration = Vector3.ZERO
		return
	if paused:
		main_acceleration = 0.0
		residual_acceleration = Vector3.ZERO
		return
	dt = maxf(dt,0.0)
	var speed := velocity.length()
	var force := acceleration.length()
	_thrust_active = force > (.7 if _thrust_active else 2.0)
	_moving = speed > (.5 if _moving else 1.2)
	var braking := _moving and _thrust_active and acceleration.dot(velocity.normalized()) < -force*.35
	var desired := Vector3.UP
	var amount := 0.0
	if braking or (_moving and not _thrust_active):
		# Retro-jets arrest motion without turning the body end-over-end.
		desired = velocity.normalized()
		amount = clampf(speed/8.0,0,1)
		mode = "BRAKE" if braking else "COAST"
	elif _thrust_active:
		desired = acceleration.normalized()
		amount = clampf(force/8.0,0,1)
		mode = "THRUST"
	else:
		mode = "IDLE"
	_idle_time = _idle_time+dt if mode=="IDLE" else 0.0
	if mode=="IDLE" and _idle_time < .45:
		desired = _direction
		amount = flight_amount
	# A new heading must persist; alternating small commands do not flap the body.
	if _direction.angle_to(desired) > DIRECTION_DEADBAND:
		if _candidate.angle_to(desired) > DIRECTION_DEADBAND:
			_candidate = desired
			_candidate_time = 0.0
		_candidate_time += dt
		if _candidate_time >= DIRECTION_DWELL:
			_direction = _candidate
			_candidate_time = 0.0
	else:
		_candidate_time = 0.0
		_candidate = _direction
	flight_amount = move_toward(flight_amount,amount,dt*(1.5 if amount>flight_amount else .8))
	var axis := Vector3.UP.cross(_direction)
	var target := Quaternion.IDENTITY
	if axis.length_squared() > .00001:
		target = Quaternion(axis.normalized(),minf(Vector3.UP.angle_to(_direction),MAX_LEAN)*flight_amount)
	var current := body_basis.get_rotation_quaternion()
	var angle := current.angle_to(target)
	var fraction := minf(1.0-exp(-dt*4.0),dt*TURN_RATE/maxf(angle,.00001))
	body_basis = Basis(current.slerp(target,fraction)).orthonormalized()
	if angle < .001: body_basis = Basis(target)
	set_jet_basis(body_basis,acceleration)

func set_jet_basis(orientation: Basis, acceleration: Vector3) -> void:
	main_acceleration = maxf(acceleration.dot(orientation.y),0.0)
	residual_acceleration = acceleration-orientation.y*main_acceleration
	if acceleration.length() <= .2:
		main_acceleration = 0.0
		residual_acceleration = Vector3.ZERO

## Two equal fixed-length bones, stable pole in the chest frame. Returns shoulder,
## elbow, capped wrist. Requested wrist stays a separate visible equipment target.
static func arm_points(shoulder: Vector3, target: Vector3, pole: Vector3, length := 4.5) -> Array[Vector3]:
	var delta := target - shoulder
	var direction := delta.normalized() if delta.length_squared() > 0.000001 else Vector3.FORWARD
	var reach := clampf(delta.length(),0.0,2.0*length-0.001)
	var bend := pole - direction * pole.dot(direction)
	if bend.length_squared() < 0.000001:
		bend = direction.cross(Vector3.UP if absf(direction.y)<0.9 else Vector3.RIGHT)
	var wrist := shoulder + direction*reach
	var elbow := shoulder + direction*reach*.5 + bend.normalized()*sqrt(maxf(length*length-reach*reach*.25,0.0))
	return [shoulder,elbow,wrist]
