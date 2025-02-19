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

# grabbing variables
var picked_object
var pull_power = 4

# sprint speed
var speed
@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var interaction = $Head/Camera3D/Interaction
@onready var hand = $Head/Camera3D/Hand

# pick objects function
func pick_object():
	var collider = interaction.get_collider()
	# check if the raycast is colliding with something
	if collider != null and collider is RigidBody3D:
		print("Colling with rigid body")
		picked_object = collider

func remove_object():
	if picked_object != null:
		picked_object = null

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

	# interact button to grab
	if Input.is_action_just_pressed("grab"):
		if picked_object == null:
			pick_object()
		elif picked_object != null:
			remove_object()
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
	
	# pulling object for grabbing
	if picked_object != null:
		# position of the object in relation to the hand calculation
		var a = picked_object.global_transform.origin
		var b = hand.global_transform.origin
		picked_object.set_linear_velocity((b-a) * pull_power)
	
	move_and_slide()

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	# will go from neg amp to amp value set here
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos
	
