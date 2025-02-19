extends CharacterBody3D


const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.01

# head bob variables
const BOB_FREQ = 2.0
const BOB_AMP = 0.08
var t_bob = 0.0

# fov variables
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

# fov constant interaction raycast
const RAY_LENGTH = 10.0

# sprint speed
var speed
@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var interact_hint = $"../PlayerUI/interact_hint"

func _ready():
	# removes the cursor from window
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# any time there is no input handler
func _unhandled_input(event):
	# following mouse
	if event is InputEventMouseMotion:
		# y * x bc when moving mouse left->right we want rotate around y axis
		# up->down mouse movement x axis camera rotation
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		# clamping so you cannot look all the way down 
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))
		
func _physics_process(delta: float) -> void:
	var mouse_position = get_viewport().get_mouse_position()
	var space_state = get_world_3d().direct_space_state
	var origin = camera.project_ray_origin(mouse_position)
	var end = origin + camera.project_ray_normal(mouse_position) * RAY_LENGTH
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	
	var result = space_state.intersect_ray(query)
	if result:
		var collider = result.collider
		if collider.has_method("on_ray_hit"):
			interact_hint.visible = true
		else:
			interact_hint.visible = false
	
	if Input.is_action_just_pressed("interact") and result.collider.has_method("on_ray_hit"):
		result.collider.on_ray_hit()
		# pick up collider
		pass
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Check sprint
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# addidng inertia
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			# the delta * (number) is how fast the player stops when not pressing a directional key higher = faster
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)

	else:
		# 3 arguments initial velocity, target velocity, decimal percent of distance between these
		# change the delta * (number) if you want the player to have more control in the air higher = more control
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 2.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 2.0)

	# head bob
	# is on floor when converted to float returns 0 or 1 for true or false
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)
	
	# FOV
	# clamp so the fov does not go out of bounds when falling
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	
	move_and_slide()

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	# will go from neg amp to amp value set here
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos
	
