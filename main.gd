extends Node2D

const SPEED := 180.0
const BUTTON_SIZE := 58.0
var player := Vector2(480, 270)
var touch_positions: Dictionary = {}
var mouse_position := Vector2(-1000, -1000)
var mouse_held := false
var facing := Vector2.DOWN
var walk_time := 0.0
var moving := false

func button_rect(direction: String) -> Rect2:
	var size := get_viewport_rect().size
	var center := Vector2(105, size.y - 105)
	var offset := Vector2.ZERO
	match direction:
		"up": offset = Vector2(0, -BUTTON_SIZE)
		"down": offset = Vector2(0, BUTTON_SIZE)
		"left": offset = Vector2(-BUTTON_SIZE, 0)
		"right": offset = Vector2(BUTTON_SIZE, 0)
	return Rect2(center + offset - Vector2.ONE * BUTTON_SIZE / 2, Vector2.ONE * BUTTON_SIZE)

func pressed(direction: String) -> bool:
	var rect := button_rect(direction)
	for position in touch_positions.values():
		if rect.has_point(position):
			return true
	return mouse_held and rect.has_point(mouse_position)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_positions[event.index] = event.position
		else:
			touch_positions.erase(event.index)
	elif event is InputEventScreenDrag:
		touch_positions[event.index] = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_held = event.pressed
		mouse_position = event.position
	elif event is InputEventMouseMotion and mouse_held:
		mouse_position = event.position

func _process(delta: float) -> void:
	var direction := Vector2(
		int(pressed("right") or Input.is_key_pressed(KEY_RIGHT)) - int(pressed("left") or Input.is_key_pressed(KEY_LEFT)),
		int(pressed("down") or Input.is_key_pressed(KEY_DOWN)) - int(pressed("up") or Input.is_key_pressed(KEY_UP))
	)
	# Keep movement four-directional when two directions are pressed.
	if direction.x != 0:
		direction.y = 0
	moving = direction != Vector2.ZERO
	if moving:
		facing = direction
		walk_time += delta * 8.0
	else:
		walk_time = 0.0
	player += direction * SPEED * delta
	var size := get_viewport_rect().size
	player = player.clamp(Vector2(20, 30), size - Vector2(20, 30))
	queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("202938"))
	for x in range(0, int(size.x) + 1, 40):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color("344255"), 1)
	for y in range(0, int(size.y) + 1, 40):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color("344255"), 1)
	draw_mannequin()
	for name in ["up", "down", "left", "right"]:
		var rect := button_rect(name)
		draw_rect(rect.grow(-2), Color(0.65, 0.76, 0.88, 0.75 if pressed(name) else 0.35))
		var c := rect.get_center()
		var vec := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}[name] as Vector2
		var side := Vector2(-vec.y, vec.x)
		draw_colored_polygon(PackedVector2Array([c + vec * 13, c - vec * 8 + side * 9, c - vec * 8 - side * 9]), Color.WHITE)

func pixel_rect(origin: Vector2, x: int, y: int, width: int, height: int, color: Color) -> void:
	draw_rect(Rect2(origin + Vector2(x, y) * 3.0, Vector2(width, height) * 3.0), color)

func draw_mannequin() -> void:
	var outline := Color("536274")
	var light := Color("e2e9eb")
	var shade := Color("aebec6")
	var dark := Color("738b99")
	var step := 0
	if moving:
		step = int(round(sin(walk_time)))
	var bob := 0 if step == 0 else -1
	var origin := player + Vector2(-24, -39 + bob * 3)
	# Draw whole-pixel blocks for a neutral, faceless placeholder figure.
	pixel_rect(origin, 4, 0, 8, 8, outline)
	pixel_rect(origin, 5, 1, 6, 6, light)
	pixel_rect(origin, 4, 8, 8, 7, outline)
	pixel_rect(origin, 5, 8, 6, 6, light)
	if facing == Vector2.UP:
		pixel_rect(origin, 5, 2, 6, 4, shade)
		pixel_rect(origin, 6, 9, 4, 4, shade)
	elif facing.x != 0:
		pixel_rect(origin, 5 if facing.x < 0 else 10, 3, 1, 2, shade)
		pixel_rect(origin, 5 if facing.x < 0 else 10, 9, 1, 4, shade)
	else:
		pixel_rect(origin, 6, 6, 4, 1, shade)
	# Opposing arms and legs alternate in short pixel steps.
	pixel_rect(origin, 2, 9 + step, 2, 5, outline)
	pixel_rect(origin, 12, 9 - step, 2, 5, outline)
	pixel_rect(origin, 3, 9 + step, 1, 4, shade)
	pixel_rect(origin, 12, 9 - step, 1, 4, shade)
	pixel_rect(origin, 5, 15, 3, 5 + step, outline)
	pixel_rect(origin, 8, 15, 3, 5 - step, outline)
	pixel_rect(origin, 6, 15, 2, 3 + step, shade)
	pixel_rect(origin, 8, 15, 2, 3 - step, shade)
	pixel_rect(origin, 5, 19 + step, 3, 1, dark)
	pixel_rect(origin, 8, 19 - step, 3, 1, dark)
