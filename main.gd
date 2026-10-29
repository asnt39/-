extends Node2D

const SPEED := 180.0
const BUTTON_SIZE := 58.0
var player := Vector2(480, 270)
var touch_positions: Dictionary = {}
var mouse_position := Vector2(-1000, -1000)
var mouse_held := false

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
	var figure := Color("e1e5eb")
	draw_circle(player + Vector2(0, -17), 8, figure)
	draw_line(player + Vector2(0, -7), player + Vector2(0, 10), figure, 9)
	draw_line(player + Vector2(-12, 0), player + Vector2(12, 0), figure, 5)
	draw_line(player + VectorFromLeg(-1), player + Vector2(-9, 24), figure, 5)
	draw_line(player + VectorFromLeg(1), player + Vector2(9, 24), figure, 5)
	for name in ["up", "down", "left", "right"]:
		var rect := button_rect(name)
		draw_rect(rect.grow(-2), Color(0.65, 0.76, 0.88, 0.75 if pressed(name) else 0.35))
		var c := rect.get_center()
		var vec := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}[name] as Vector2
		var side := Vector2(-vec.y, vec.x)
		draw_colored_polygon(PackedVector2Array([c + vec * 13, c - vec * 8 + side * 9, c - vec * 8 - side * 9]), Color.WHITE)

func VectorFromLeg(side: int) -> Vector2:
	return Vector2(side * 2, 9)
