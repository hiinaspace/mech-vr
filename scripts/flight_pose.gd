extends RefCounted
## Authored visual approximation in cockpit axes (+Y spine, -Z forward).
## No forces or physics state are changed. Inputs must exclude collision impulses.
const MAX_LEAN := deg_to_rad(82.0)
const TURN_RATE := deg_to_rad(110.0)
var body_basis := Basis.IDENTITY
var main_acceleration := 0.0
var residual_acceleration := Vector3.ZERO
var flight_amount := 0.0

func step(dt: float, velocity: Vector3, acceleration: Vector3, paused := false) -> void:
	if not velocity.is_finite() or not acceleration.is_finite() or not is_finite(dt):
		main_acceleration = 0.0
		residual_acceleration = Vector3.ZERO
		return
	if paused:
		main_acceleration = 0.0
		residual_acceleration = Vector3.ZERO
		return
	var direction := Vector3.UP
	var amount := 0.0
	if acceleration.length() > 0.2:
		direction = acceleration.normalized()
		amount = clampf(acceleration.length() / 8.0, 0.0, 1.0)
	elif velocity.length() > 0.2:
		direction = velocity.normalized()
		amount = clampf(velocity.length() / 8.0, 0.0, 1.0)
	# Bounded hemisphere avoids an upside-down flip during descent/reversal.
	var axis := Vector3.UP.cross(direction)
	var target := Quaternion.IDENTITY
	if axis.length_squared() > 0.00001:
		target = Quaternion(axis.normalized(), minf(Vector3.UP.angle_to(direction), MAX_LEAN) * amount)
	var current := body_basis.get_rotation_quaternion()
	var angle := current.angle_to(target)
	var fraction := minf(maxf(dt,0.0) * TURN_RATE / maxf(angle,0.00001),1.0)
	body_basis = Basis(current.slerp(target,fraction)).orthonormalized()
	flight_amount = move_toward(flight_amount,amount,maxf(dt,0.0)*2.0)
	main_acceleration = maxf(acceleration.dot(body_basis.y),0.0)
	residual_acceleration = acceleration - body_basis.y * main_acceleration
	if acceleration.length() <= 0.2:
		main_acceleration = 0.0
		residual_acceleration = Vector3.ZERO

## Two equal fixed-length bones, stable pole in the chest frame. Returns shoulder,
## elbow, capped wrist. Requested wrist stays a separate visible equipment target.
static func arm_points(shoulder: Vector3, target: Vector3, pole: Vector3, length := 4.5) -> Array[Vector3]:
	var delta := target - shoulder
	var direction := delta.normalized() if delta.length_squared() > 0.000001 else Vector3.FORWARD
	var reach := clampf(delta.length(),0.02,2.0*length-0.001)
	var bend := pole - direction * pole.dot(direction)
	if bend.length_squared() < 0.000001:
		bend = direction.cross(Vector3.UP if absf(direction.y)<0.9 else Vector3.RIGHT)
	var wrist := shoulder + direction*reach
	var elbow := shoulder + direction*reach*.5 + bend.normalized()*sqrt(maxf(length*length-reach*reach*.25,0.0))
	return [shoulder,elbow,wrist]
